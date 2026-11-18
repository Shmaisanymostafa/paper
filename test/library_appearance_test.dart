import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/main.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  test('rail defaults, validation and field-scoped persistence', () async {
    expect(
      PaperSettings.fromJson({'appearance': 'system', 'language': 'en'})
          .libraryRailCollapsed,
      false,
    );
    for (final value in ['true', 1, []]) {
      expect(
        () => PaperSettings.fromJson({
          'appearance': 'system',
          'language': 'en',
          'libraryRailCollapsed': value,
        }),
        throwsA(isA<LibraryFormatException>()),
      );
    }
    final dir = await Directory.systemTemp.createTemp('paper-rail-settings-');
    try {
      final repo = LibraryRepository(dir);
      final bytes = await File('assets/sample.pdf').readAsBytes();
      final doc = await repo.importPdf(
        name: 'sample.pdf',
        bytes: Stream.value(bytes),
      );
      await repo.setSettings(
        const PaperSettings(
          language: 'ar',
          pinnedTools: 3,
          readerPanelVisible: false,
        ),
      );
      await repo.setLibraryRailCollapsed(true);
      await repo.setDisplaySettings(
        const PaperSettings(appearance: Appearance.dark, language: 'ar'),
      );
      final state = await LibraryRepository(dir).load();
      expect(state.settings.libraryRailCollapsed, true);
      expect(state.settings.readerPanelVisible, false);
      expect(state.settings.pinnedTools, 3);
      expect(state.settings.appearance, Appearance.dark);
      expect(state.documents.single.toJson(), doc.toJson());
      expect(await repo.documentFile(doc.id).readAsBytes(), bytes);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  for (final language in ['en', 'ar']) {
    for (final width in [360.0, 1280.0]) {
      testWidgets(
        '$language appearance preview/cancel/save and rail at $width',
        (tester) async {
          final dir = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('paper-appearance-'),
          ))!;
          final repo = LibraryRepository(dir);
          final s = PaperStrings(language);
          await tester.runAsync(
            () => repo.setSettings(PaperSettings(language: language)),
          );
          tester.view.physicalSize = Size(width, width < 960 ? 640 : 700);
          if (width < 960) {
            tester.platformDispatcher.textScaleFactorTestValue = 2;
          }
          tester.view.devicePixelRatio = 1;
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
            await tester.runAsync(() => dir.delete(recursive: true));
          });
          Future<void> load() async {
            await tester.pumpWidget(PaperApp(repository: repo));
            for (
              var i = 0;
              i < 50 && find.byType(TextField).evaluate().isEmpty;
              i++
            ) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump();
            }
            await tester.pumpAndSettle();
          }

          await load();
          if (width >= 960) {
            await tester.tap(find.byTooltip(s['libraryCollapseRail']));
            for (
              var i = 0;
              i < 50 &&
                  find.byTooltip(s['libraryExpandRail']).evaluate().isEmpty;
              i++
            ) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump();
            }
            expect(find.byTooltip(s['libraryExpandRail']), findsOneWidget);
            expect(
              (await tester.runAsync(repo.load))!.settings.libraryRailCollapsed,
              true,
            );
          }
          await tester.tap(find.byTooltip(s['libraryAppearance']));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          final before = (await tester.runAsync(repo.load))!.toJson();
          Future<void> chooseDark() async {
            await tester.tap(find.byType(DropdownButtonFormField<Appearance>));
            await tester.pumpAndSettle();
            await tester.tap(find.text(s['dark']).last);
            await tester.pumpAndSettle();
          }

          await chooseDark();
          final preview = tester.widget<Container>(
            find.byKey(const ValueKey('library-appearance-preview')),
          );
          expect(
            (preview.decoration! as BoxDecoration).color,
            const Color(0xFF10232C),
          );
          expect(
            tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
            ThemeMode.system,
          );
          await tester.tap(find.widgetWithText(TextButton, s['cancel']));
          await tester.pumpAndSettle();
          expect((await tester.runAsync(repo.load))!.toJson(), before);
          await tester.tap(find.byTooltip(s['libraryAppearance']));
          await tester.pumpAndSettle();
          await chooseDark();
          await tester.tap(find.widgetWithText(FilledButton, s['save']));
          // Theme changes before the repository reload has completed. Pump
          // until the whole UI operation finishes before starting another read.
          for (var i = 0; i < 100; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
            if (tester
                        .widget<MaterialApp>(find.byType(MaterialApp))
                        .themeMode ==
                    ThemeMode.dark &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty) {
              break;
            }
          }
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(
            tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
            ThemeMode.dark,
          );
          expect(
            (await tester.runAsync(repo.load))!.settings.appearance,
            Appearance.dark,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await load();
          expect(
            tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
            ThemeMode.dark,
          );
          if (width >= 960) {
            expect(find.byTooltip(s['libraryExpandRail']), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
