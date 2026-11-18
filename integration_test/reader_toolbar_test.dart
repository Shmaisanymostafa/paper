import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/data/offline_policy.dart';
import 'package:cave_paper/ui/reader_screen.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'offline reader toolbar cancel, persistence, responsive RTL and search',
    (tester) => HttpOverrides.runWithHttpOverrides(() async {
      final dir = await Directory.systemTemp.createTemp(
        'paper-toolbar-native-',
      );
      try {
        await pdfrxFlutterInitialize();
        final asset = await rootBundle.load('assets/sample.pdf');
        final bytes = asset.buffer.asUint8List(
          asset.offsetInBytes,
          asset.lengthInBytes,
        );
        final repo = LibraryRepository(dir);
        final document = await repo.importPdf(
          name: 'sample.pdf',
          bytes: Stream.value(bytes),
        );
        Future<void> waitFor(bool Function() ready) async {
          for (var i = 0; i < 100 && !ready(); i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(ready(), isTrue);
        }

        Future<void> open(String language, Size size) async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.binding.setSurfaceSize(size);
          final s = PaperStrings(language);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: ReaderScreen(
                repository: repo,
                document: document,
                strings: s,
              ),
            ),
          );
          await waitFor(() {
            final menu = find.byType(PopupMenuButton<String>);
            return menu.evaluate().isNotEmpty &&
                tester.widget<PopupMenuButton<String>>(menu).enabled;
          });
        }

        Future<void> customize(String language) async {
          final s = PaperStrings(language);
          await tester.tap(find.byType(PopupMenuButton<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text(s['toolbarCustomize']));
          await tester.pumpAndSettle();
        }

        await open('en', const Size(1280, 900));
        await customize('en');
        await tester.tap(
          find.widgetWithText(CheckboxListTile, 'Add a page note'),
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect((await repo.load()).settings.pinnedTools, 0);
        await customize('en');
        await tester.tap(
          find.widgetWithText(CheckboxListTile, 'Add a page note'),
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect((await repo.load()).settings.pinnedTools, 1);
        expect(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Add a page note',
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Search this PDF',
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Cave Paper');
        await waitFor(() => find.byType(ListTile).evaluate().isNotEmpty);
        expect(tester.takeException(), isNull);
        await open('ar', const Size(390, 844));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is IconButton && w.tooltip == PaperStrings('ar')['newNote'],
          ),
          findsOneWidget,
        );
        expect(
          Directionality.of(tester.element(find.byType(ReaderScreen))),
          TextDirection.rtl,
        );
        await customize('ar');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(PaperStrings('ar')['cancel']));
        await tester.pumpAndSettle();
        expect((await LibraryRepository(dir).load()).settings.pinnedTools, 1);
        expect(await repo.documentFile(document.id).readAsBytes(), bytes);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } finally {
        await tester.binding.setSurfaceSize(null);
        await dir.delete(recursive: true);
      }
    }, OfflineHttpOverrides()),
  );
}
