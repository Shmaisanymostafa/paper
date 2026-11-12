import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/main.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  test('English and Arabic have matching translation keys', () {
    expect(PaperStrings.en.keys.toSet(), PaperStrings.ar.keys.toSet());
    expect(PaperStrings.ar.values.every((v) => v.trim().isNotEmpty), true);
  });
  for (final language in ['en', 'ar']) {
    for (final width in [360.0, 1280.0]) {
      testWidgets('$language library at $width does not overflow', (
        tester,
      ) async {
        final dir = await tester.runAsync(
          () => Directory.systemTemp.createTemp('paper-widget-'),
        );
        final repo = LibraryRepository(dir!);
        await tester.runAsync(
          () => repo.setSettings(PaperSettings(language: language)),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(() => dir.delete(recursive: true));
        });
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(PaperApp(repository: repo));
        for (
          var attempt = 0;
          attempt < 50 &&
              find.text(PaperStrings(language)['open']).evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text(PaperStrings(language)['open']), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
