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
      testWidgets('$language library at $width does not overflow', (tester) async {
        final dir = await Directory.systemTemp.createTemp('paper-widget-');
        addTearDown(() async => dir.delete(recursive: true));
        final repo = LibraryRepository(dir);
        await repo.setSettings(PaperSettings(language: language));
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(PaperApp(repository: repo));
        await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
        expect(find.text(PaperStrings(language)['open']), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
