import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/data/offline_policy.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/services/page_copy.dart';

void main() {
  test(
    'rotated page copies reopen with correct orientation and untouched original',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final dir = await Directory.systemTemp.createTemp('paper-rotation-');
      try {
        await pdfrxInitialize(tmpPath: dir.path);
        final bytes = await File('assets/sample.pdf').readAsBytes();
        final repo = LibraryRepository(
          await Directory('${dir.path}/library').create(),
        );
        final original = await repo.importPdf(
          name: 'sample.pdf',
          bytes: Stream.value(bytes),
        );
        final before = (await repo.load()).toJson();
        final source = await PdfDocument.openData(bytes);
        try {
          final first = source.pages.first;
          final text = (await first.loadText())!.fullText;
          Uint8List? rotatedBytes;
          for (final turns in [0, 1, 2, 3]) {
            final encoded = await PageCopy().create(
              repository: repo,
              document: original,
              pages: [1, 1],
              clockwiseQuarterTurns: turns,
            );
            if (turns == 1) rotatedBytes = encoded;
            final copy = await PdfDocument.openData(encoded);
            try {
              expect(copy.pages.length, 2);
              for (final page in copy.pages) {
                expect(page.rotation.index, (first.rotation.index + turns) % 4);
                expect(
                  page.width,
                  closeTo(turns.isOdd ? first.height : first.width, .1),
                );
                expect(
                  page.height,
                  closeTo(turns.isOdd ? first.width : first.height, .1),
                );
                final extracted = (await page.loadText())!.fullText;
                if (turns == 0) {
                  expect(extracted, text);
                } else {
                  // PDFium derives reading order from rotated page geometry.
                  // Preserve all tokens/counts, not a false exact-order promise.
                  final actualWords = extracted.split(RegExp(r'\s+'))..sort();
                  final originalWords = text.split(RegExp(r'\s+'))..sort();
                  expect(actualWords, originalWords);
                }
                final image = await page.render(width: 120, height: 120);
                expect(image, isNotNull);
                image?.dispose();
              }
            } finally {
              await copy.dispose();
            }
          }
          final rotatedRepo = LibraryRepository(
            await Directory('${dir.path}/rotated-library').create(),
          );
          final rotatedSource = await rotatedRepo.importPdf(
            name: 'rotated.pdf',
            bytes: Stream.value(rotatedBytes!),
          );
          final composedBytes = await PageCopy().create(
            repository: rotatedRepo,
            document: rotatedSource,
            pages: [1],
            clockwiseQuarterTurns: 3,
          );
          final composed = await PdfDocument.openData(composedBytes);
          try {
            expect(composed.pages.first.rotation, first.rotation);
            expect(composed.pages.first.width, closeTo(first.width, .1));
            expect(composed.pages.first.height, closeTo(first.height, .1));
          } finally {
            await composed.dispose();
          }
          expect(
            await rotatedRepo.documentFile(rotatedSource.id).readAsBytes(),
            rotatedBytes,
          );
          for (final turns in [-1, 4]) {
            await expectLater(
              PageCopy().create(
                repository: repo,
                document: original,
                pages: [1],
                clockwiseQuarterTurns: turns,
              ),
              throwsA(isA<LibraryFormatException>()),
            );
          }
        } finally {
          await source.dispose();
        }
        expect((await repo.load()).toJson(), before);
        expect(await repo.documentFile(original.id).readAsBytes(), bytes);
        await repo.verifyDocument(original);
      } finally {
        await dir.delete(recursive: true);
      }
    }, OfflineHttpOverrides()),
    skip: Platform.environment['PDFIUM_PATH'] == null
        ? 'Requires audited local PDFium.'
        : false,
  );
}
