import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/data/library_repository.dart';

void main() {
  test('old settings load without favorite tools', () {
    expect(
      PaperSettings.fromJson({'appearance': 'system', 'language': 'en'})
          .pinnedTools,
      0,
    );
  });
  test('favorite tool bits round-trip and survive theme edits', () {
    const settings = PaperSettings(pinnedTools: 161);
    final loaded = PaperSettings.fromJson(settings.toJson());
    expect(loaded.copyWith(language: 'ar').pinnedTools, 161);
    expect(loaded.copyWith(appearance: Appearance.dark).pinnedTools, 161);
  });
  test('invalid favorite masks are rejected', () {
    for (final value in [-1, 256, 2.5, '1', true, []]) {
      expect(
        () => PaperSettings.fromJson({
          'appearance': 'system',
          'language': 'en',
          'pinnedTools': value,
        }),
        throwsA(isA<LibraryFormatException>()),
      );
    }
  });
  test(
    'favorite updates preserve language, theme and documents after reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('paper-toolbar-test-');
      try {
        final repo = LibraryRepository(dir);
        final bytes = await File('assets/sample.pdf').readAsBytes();
        final document = await repo.importPdf(
          name: 'sample.pdf',
          bytes: Stream.value(bytes),
        );
        await repo.setSettings(
          const PaperSettings(language: 'ar', appearance: Appearance.dark),
        );
        await Future.wait([repo.setPinnedTools(3), repo.setPinnedTools(129)]);
        // The app-level display dialog can hold settings from before a reader
        // changed its pins; those stale bits must never overwrite current pins.
        await repo.setDisplaySettings(
          const PaperSettings(language: 'ar', appearance: Appearance.dark),
        );
        final state = await LibraryRepository(dir).load();
        expect(state.settings.language, 'ar');
        expect(state.settings.appearance, Appearance.dark);
        expect(state.settings.pinnedTools, 129);
        expect(state.documents.single.toJson(), document.toJson());
        expect(await repo.documentFile(document.id).readAsBytes(), bytes);
        await repo.verifyDocument(document);
        expect(
          () => repo.setPinnedTools(-1),
          throwsA(isA<LibraryFormatException>()),
        );
        expect((await repo.load()).settings.pinnedTools, 129);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
