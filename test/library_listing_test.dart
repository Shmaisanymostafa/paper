import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/domain/library_listing.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/main.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  test('filter/sort is deterministic and leaves input metadata unchanged', () {
    PaperDocument doc(String id, String title, int imported, int opened) =>
        PaperDocument(
          id: id * 64,
          title: title,
          byteLength: 8,
          importedAt: DateTime.utc(2026, 1, imported),
          lastOpenedAt: DateTime.utc(2026, 1, opened),
        );
    final docs = [
      doc('a', 'Zulu', 3, 1),
      doc('b', 'Alpha', 1, 3),
      doc('c', 'alpha', 2, 2),
    ];
    final before = docs.map((d) => d.toJson()).toList();
    expect(
      libraryListing(
        docs,
        query: '',
        sort: LibrarySort.recent,
      ).map((d) => d.id),
      [docs[1].id, docs[2].id, docs[0].id],
    );
    expect(
      libraryListing(
        docs,
        query: '',
        sort: LibrarySort.newest,
      ).map((d) => d.id),
      [docs[0].id, docs[2].id, docs[1].id],
    );
    expect(
      libraryListing(
        docs,
        query: '  ALP ',
        sort: LibrarySort.title,
      ).map((d) => d.id),
      [docs[1].id, docs[2].id],
    );
    expect(
      libraryListing(docs, query: 'missing', sort: LibrarySort.recent),
      isEmpty,
    );
    expect(docs.map((d) => d.toJson()).toList(), before);
  });
  for (final language in ['en', 'ar']) {
    testWidgets('$language short keyboard and large text remain scrollable', (
      tester,
    ) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('paper-small-listing-'),
      ))!;
      final repo = LibraryRepository(dir);
      final s = PaperStrings(language);
      await tester.runAsync(
        () => repo.setSettings(PaperSettings(language: language)),
      );
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.runAsync(() => dir.delete(recursive: true));
      });
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
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(s['empty']),
        150,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(s['empty']), findsOneWidget);
      expect(find.text(s['noMatch']), findsNothing);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      final clear = find.widgetWithText(TextButton, s['libraryClearSearch']);
      await tester.scrollUntilVisible(
        clear,
        150,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -150,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final language in ['en', 'ar']) {
    testWidgets('$language search clear count and sort preserve library', (
      tester,
    ) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('paper-listing-'),
      ))!;
      final repo = LibraryRepository(dir);
      final s = PaperStrings(language);
      await tester.runAsync(() async {
        final pdf = await File('assets/sample.pdf').readAsBytes();
        await repo.importPdf(name: 'Zulu.pdf', bytes: Stream.value(pdf));
        await repo.importPdf(
          name: 'Alpha.pdf',
          bytes: Stream.value([...pdf, 10, 37, 32, 50, 10]),
        );
        await repo.setSettings(PaperSettings(language: language));
      });
      final before = (await tester.runAsync(repo.load))!.toJson();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => dir.delete(recursive: true));
      });
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      expect(
        find.text(
          s['libraryResultCount']
              .replaceAll('{shown}', '2')
              .replaceAll('{total}', '2'),
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text(s['librarySearchDetail']), findsOneWidget);
      expect(find.text(s['emptyDetail']), findsNothing);
      await tester.tap(
        find.widgetWithText(TextButton, s['libraryClearSearch']),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pumpAndSettle();
      expect(
        find.text(
          s['libraryResultCount']
              .replaceAll('{shown}', '1')
              .replaceAll('{total}', '2'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip(s['libraryClearSearch']));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<LibrarySort>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s['librarySortTitle']).last);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Alpha.pdf')).dy,
        lessThan(tester.getTopLeft(find.text('Zulu.pdf')).dy),
      );
      expect((await tester.runAsync(repo.load))!.toJson(), before);
      expect(tester.takeException(), isNull);
    });
  }
}
