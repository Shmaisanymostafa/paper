import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/main.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  for (final language in ['en', 'ar']) {
    for (final width in [390.0, 1280.0]) {
      testWidgets('$language actual library capture at $width', (tester) async {
        final dir = await tester.runAsync(
          () => Directory.systemTemp.createTemp('paper-capture-'),
        );
        final repo = LibraryRepository(dir!);
        await tester.runAsync(() async {
          await repo.setSettings(
            PaperSettings(language: language, appearance: Appearance.light),
          );
          final data = await rootBundle.load('assets/sample.pdf');
          await repo.importPdf(
            name: 'Cave Paper • Welcome.pdf',
            bytes: Stream.value(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            ),
          );
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          for (final entry in {
            'IBMPlexSans': 'IBMPlexSans-Regular.ttf',
            'IBMPlexSansArabic': 'IBMPlexSansArabic-Regular.ttf',
          }.entries) {
            await (FontLoader(
              entry.key,
            )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
          }
        });
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: PaperApp(repository: repo),
          ),
        );
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
        expect(tester.takeException(), isNull);
        expect(find.text('Cave Paper • Welcome.pdf'), findsOneWidget);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final out = File(
            'evidence/local/cave-paper-$language-${width.toInt()}.png',
          );
          await out.parent.create(recursive: true);
          await out.writeAsBytes(
            bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => dir.delete(recursive: true));
      }, skip: !const bool.fromEnvironment('PAPER_CAPTURE'));
    }
  }
}
