import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/data/offline_policy.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/services/pdf_annotation_reader.dart';
import 'package:cave_paper/services/pdf_annotation_writer.dart';

typedef _Annot = ({
  int subtype,
  String contents,
  String name,
  List<double> rect,
});

/// Reads every annotation back with PDFium, independent of the writer.
Future<List<List<_Annot>>> _readAnnotations(PdfDocument pdf) =>
    pdf.useNativeDocumentHandle((handle) {
      final lib = pdfium.getPdfium(modulePath: Pdfrx.pdfiumModulePath);
      final doc = pdfium.FPDF_DOCUMENT.fromAddress(handle);
      return using((arena) {
        String text(pdfium.FPDF_ANNOTATION annot, String key) {
          final k = key.toNativeUtf8(allocator: arena).cast<Char>();
          final size = lib.FPDFAnnot_GetStringValue(annot, k, nullptr, 0);
          final buffer = arena<Uint16>(size ~/ 2 + 1);
          lib.FPDFAnnot_GetStringValue(annot, k, buffer.cast(), size);
          return String.fromCharCodes(
            buffer.asTypedList(size ~/ 2).takeWhile((c) => c != 0),
          );
        }

        final rect = arena<pdfium.FS_RECTF>();
        return [
          for (var p = 0; p < lib.FPDF_GetPageCount(doc); p++)
            () {
              final page = lib.FPDF_LoadPage(doc, p);
              try {
                return [
                  for (var i = 0; i < lib.FPDFPage_GetAnnotCount(page); i++)
                    () {
                      final annot = lib.FPDFPage_GetAnnot(page, i);
                      try {
                        lib.FPDFAnnot_GetRect(annot, rect);
                        return (
                          subtype: lib.FPDFAnnot_GetSubtype(annot),
                          contents: text(annot, 'Contents'),
                          name: text(annot, 'NM'),
                          rect: [
                            rect.ref.left,
                            rect.ref.top,
                            rect.ref.right,
                            rect.ref.bottom,
                          ],
                        );
                      } finally {
                        lib.FPDFPage_CloseAnnot(annot);
                      }
                    }(),
                ];
              } finally {
                lib.FPDF_ClosePage(page);
              }
            }(),
        ];
      });
    });

void main() {
  test(
    'highlights and notes are written as standard annotations in a new copy',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final dir = await Directory.systemTemp.createTemp('paper-annotate-');
      try {
        await pdfrxInitialize(tmpPath: dir.path);
        final bytes = await File('assets/sample.pdf').readAsBytes();
        final repo = LibraryRepository(
          await Directory('${dir.path}/library').create(),
        );
        var original = await repo.importPdf(
          name: 'sample.pdf',
          bytes: Stream.value(bytes),
        );

        // Highlight the first line of page 1 the way the reader does.
        final source = await PdfDocument.openData(bytes);
        late List<HighlightBox> boxes;
        late String selected;
        try {
          final text = await source.pages.first.loadStructuredText();
          const phrase = 'This is a synthetic PDF';
          final start = text.fullText.indexOf(phrase);
          expect(start, greaterThanOrEqualTo(0));
          final range = PdfPageTextRange(
            pageText: text,
            start: start,
            end: start + phrase.length,
          );
          selected = range.text;
          expect(selected, phrase);
          boxes = range
              .enumerateFragmentBoundingRects()
              .map((f) => f.bounds)
              .map((r) => HighlightBox(r.left, r.top, r.right, r.bottom))
              .toList();
        } finally {
          await source.dispose();
        }
        final notes = [
          PaperNote(
            id: 'h1',
            page: 1,
            text: 'Read this first — اقرأ هذا أولاً',
            boxes: boxes,
            color: 0x4CC38A,
            createdAt: DateTime.utc(2026, 11, 26, 9, 30),
          ),
          PaperNote(
            id: 'n1',
            page: 2,
            text: 'Page note',
            createdAt: DateTime.utc(2026, 11, 26),
          ),
          PaperNote(
            id: 'n2',
            page: 2,
            text: 'Second note',
            createdAt: DateTime.utc(2026, 11, 26),
          ),
          PaperNote(
            id: 'd1',
            page: 3,
            text: '',
            color: 0x5BA8F5,
            ink: [
              InkStroke([100, 100, 150, 140, 200, 100]),
              InkStroke([100, 200, 200, 200]),
            ],
            createdAt: DateTime.utc(2026, 11, 26),
          ),
        ];
        await repo.updateDocument(
          original.id,
          (d) => d.copyWith(notes: notes, pageCount: 3),
        );
        original = (await repo.load()).find(original.id)!;
        final before = await repo.documentFile(original.id).readAsBytes();

        final saved = await PdfAnnotationWriter().saveToLibrary(
          repository: repo,
          document: original,
          title: 'sample (highlighted).pdf',
        );
        expect(saved.id, isNot(original.id));
        final state = await repo.load();
        expect(state.find(saved.id)!.title, 'sample (highlighted).pdf');
        expect(state.find(saved.id)!.notes, isEmpty);
        expect(state.find(saved.id)!.pageCount, 3);
        // The source and its notes are untouched.
        expect(await repo.documentFile(original.id).readAsBytes(), before);
        expect(state.find(original.id)!.notes.length, 4);

        final out = await repo.documentFile(saved.id).readAsBytes();
        // For checking the result in other PDF apps by hand.
        final keep = Platform.environment['ANNOTATED_PDF_OUT'];
        if (keep != null) await File(keep).writeAsBytes(out);
        // Incremental save: the original bytes come first, unchanged.
        expect(out.sublist(0, bytes.length), bytes);

        final sourcePdf = await PdfDocument.openData(bytes);
        final existing = await _readAnnotations(sourcePdf);
        await sourcePdf.dispose();
        final pdf = await PdfDocument.openData(out);
        try {
          final all = await _readAnnotations(pdf);
          // Annotations already in the PDF (the sample's links) are kept,
          // and the new ones follow them.
          for (var p = 0; p < all.length; p++) {
            expect(
              all[p].sublist(0, existing[p].length).toString(),
              existing[p].toString(),
            );
          }
          expect(existing[2], isNotEmpty);
          final annots = [
            for (var p = 0; p < all.length; p++)
              all[p].sublist(existing[p].length),
          ];
          expect(annots[0].length, 1);
          final h = annots[0].single;
          expect(h.subtype, pdfium.FPDF_ANNOT_HIGHLIGHT);
          expect(h.contents, notes[0].text);
          expect(h.name, 'cave-paper-h1');
          // The highlight sits over the selected text (sample has no offset
          // page box, so page and stored coordinates match).
          final r = highlightRect(boxes);
          expect(h.rect[0], closeTo(r.left, 0.5));
          expect(h.rect[2], closeTo(r.right, 0.5));
          expect(selected, isNotEmpty);

          expect(annots[1].map((a) => a.subtype), [
            pdfium.FPDF_ANNOT_TEXT,
            pdfium.FPDF_ANNOT_TEXT,
          ]);
          expect(annots[1].map((a) => a.contents), [
            'Page note',
            'Second note',
          ]);
          // Sticky notes stack down the left edge without overlapping.
          expect(annots[1][0].rect[3], greaterThan(annots[1][1].rect[1]));
          expect(annots[2].single.subtype, pdfium.FPDF_ANNOT_INK);
          // The drawing's box covers its strokes plus the line width.
          expect(annots[2].single.rect[0], closeTo(98, 0.5));
          expect(annots[2].single.rect[2], closeTo(202, 0.5));

          // The read-back used by the notes panel finds all four, with the
          // marked text, the comments and the chosen colours.
          final embedded = await PdfAnnotationReader().read(pdf);
          final ours = embedded
              .where((e) => e.kind != EmbeddedKind.note || e.page == 2)
              .toList();
          final highlight = ours.firstWhere(
            (e) => e.kind == EmbeddedKind.highlight,
          );
          expect(highlight.page, 1);
          expect(highlight.quote, 'This is a synthetic PDF');
          expect(highlight.comment, notes[0].text);
          expect(highlight.color, 0x4CC38A);
          expect(
            ours.where((e) => e.kind == EmbeddedKind.note).map((e) => e.label),
            ['Page note', 'Second note'],
          );
          final drawing = ours.singleWhere(
            (e) => e.kind == EmbeddedKind.drawing,
          );
          expect((drawing.page, drawing.color), (3, 0x5BA8F5));
          final fromFile = await PdfAnnotationReader().readFile(
            repo.documentFile(saved.id).path,
          );
          expect(fromFile.length, embedded.length);
          expect(
            fromFile.firstWhere((e) => e.kind == EmbeddedKind.highlight).color,
            0x4CC38A,
          );
        } finally {
          await pdf.dispose();
        }

        // Protected PDFs are refused and the library is left as it was.
        for (final name in ['assembly-restricted', 'password-protected']) {
          final protectedBytes = await File('test/fixtures/$name.pdf')
              .readAsBytes();
          var protected = await repo.importPdf(
            name: '$name.pdf',
            bytes: Stream.value(protectedBytes),
          );
          await repo.updateDocument(
            protected.id,
            (d) => d.copyWith(notes: [notes[1]]),
          );
          protected = (await repo.load()).find(protected.id)!;
          final libraryBefore = (await repo.load()).toJson();
          await expectLater(
            PdfAnnotationWriter().saveToLibrary(
              repository: repo,
              document: protected,
              title: 'x.pdf',
            ),
            throwsA(isA<LibraryFormatException>()),
          );
          expect((await repo.load()).toJson(), libraryBefore);
        }
      } finally {
        await dir.delete(recursive: true);
      }
    }, OfflineHttpOverrides()),
    skip: Platform.environment['PDFIUM_PATH'] == null
        ? 'Set PDFIUM_PATH to the audited local native library for this headless integration.'
        : false,
  );

  group('placement helpers', () {
    const page = (left: 0.0, top: 800.0, right: 600.0, bottom: 0.0);
    test('sticky notes start at the shown top-left for every rotation', () {
      final upright = stickyNoteRect(page, 0, 0);
      expect(upright.left, 12);
      expect(upright.top, 788);
      // Rotated a quarter turn: the shown top-left is the stored bottom-left.
      final quarter = stickyNoteRect(page, 1, 0);
      expect(quarter.left, 12);
      expect(quarter.bottom, 12);
      final half = stickyNoteRect(page, 2, 0);
      expect(half.right, 588);
      expect(half.bottom, 12);
      final three = stickyNoteRect(page, 3, 0);
      expect(three.right, 588);
      expect(three.top, 788);
    });

    test('many sticky notes wrap into a new column and stay on the page', () {
      final rects = [for (var i = 0; i < 60; i++) stickyNoteRect(page, 0, i)];
      for (final r in rects) {
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.bottom, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(600));
      }
      expect(rects.last.left, greaterThan(rects.first.left));
    });

    test('word boxes on one line merge; separate lines stay apart', () {
      final merged = mergeLineBoxes([
        HighlightBox(10, 100, 40, 90),
        HighlightBox(43, 101, 80, 90),
        HighlightBox(10, 80, 50, 70),
        HighlightBox(300, 80, 320, 70),
      ]);
      expect(merged.map((b) => b.toJson()), [
        [10, 101, 80, 90],
        [10, 80, 50, 70],
        [300, 80, 320, 70],
      ]);
    });

    test('dates use the PDF format and highlight bounds cover all boxes', () {
      expect(pdfDate(DateTime.utc(2026, 1, 2, 3, 4, 5)), 'D:20260102030405Z');
      final r = highlightRect([
        HighlightBox(10, 50, 40, 40),
        HighlightBox(5, 38, 30, 28),
      ]);
      expect(r, (left: 5.0, top: 50.0, right: 40.0, bottom: 28.0));
    });
  });
}
