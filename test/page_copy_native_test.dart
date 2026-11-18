import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/data/offline_policy.dart';
import 'package:cave_paper/services/page_copy.dart';
import 'package:cave_paper/domain/library.dart';

void main() {
  test(
    'real PDF page copy preserves order, text, render and original',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final dir = await Directory.systemTemp.createTemp('paper-page-copy-');
      try {
        await pdfrxInitialize(tmpPath: dir.path);
        final bytes = await File('assets/sample.pdf').readAsBytes();
        final repo = LibraryRepository(dir);
        final original = await repo.importPdf(
          name: 'sample.pdf',
          bytes: Stream.value(bytes),
        );
        final before = (await repo.load()).toJson();
        final source = await PdfDocument.openData(bytes);
        final sourceTexts = <String>[];
        try {
          for (final page in source.pages) {
            sourceTexts.add((await page.loadText())!.fullText);
          }
        } finally {
          await source.dispose();
        }
        final edited = await PageCopy().create(
          repository: repo,
          document: original,
          pages: [3, 1, 3],
        );
        final copyFile = File('${dir.path}/saved-copy.pdf');
        await copyFile.writeAsBytes(edited, flush: true);
        final copy = await PdfDocument.openFile(copyFile.path);
        try {
          expect(copy.pages.length, 3);
          for (var i = 0; i < 3; i++) {
            expect(
              (await copy.pages[i].loadText())!.fullText,
              sourceTexts[[2, 0, 2][i]],
            );
            final image = await copy.pages[i].render(width: 100, height: 140);
            expect(image, isNotNull);
            image?.dispose();
          }
        } finally {
          await copy.dispose();
        }
        await expectLater(
          PageCopy().create(repository: repo, document: original, pages: [4]),
          throwsA(isA<LibraryFormatException>()),
        );
        expect((await repo.load()).toJson(), before);
        expect(await repo.documentFile(original.id).readAsBytes(), bytes);
        await repo.verifyDocument(original);
      } finally {
        await dir.delete(recursive: true);
      }
    }, OfflineHttpOverrides()),
    skip: Platform.environment['PDFIUM_PATH'] == null
        ? 'Set PDFIUM_PATH to the audited local native library for this headless integration.'
        : false,
  );
}
