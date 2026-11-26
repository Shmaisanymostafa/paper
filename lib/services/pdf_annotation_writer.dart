// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

import '../data/library_repository.dart';
import '../domain/library.dart';

/// Writes Cave Paper's highlights, drawings and notes into a new copy of a PDF
/// as standard PDF annotations that other readers show: a highlight for each
/// highlighted passage (its note text as the comment), an ink annotation for
/// each drawing, and a sticky note for each note without either.
///
/// The copy is saved incrementally: the original bytes come first, unchanged,
/// followed by the new annotations. That keeps forms, outlines and existing
/// annotations, and does not alter what an earlier signature covered. The
/// source file and its library entry are never changed.
class PdfAnnotationWriter {
  static const maxSourceBytes = 64 * 1024 * 1024;

  /// Pen line width in PDF points, as drawn in the reader.
  static const penWidth = 2.0;

  /// The PDF bytes with every note of [document] written in.
  Future<Uint8List> build({
    required LibraryRepository repository,
    required PaperDocument document,
  }) async {
    final notes = List<PaperNote>.of(document.notes);
    if (notes.isEmpty) {
      throw const LibraryFormatException('There are no notes to save.');
    }
    if (document.byteLength > maxSourceBytes) {
      throw const LibraryFormatException('PDF is too large to annotate.');
    }
    await repository.verifyDocument(document);
    final file = repository.documentFile(document.id);
    final original = await file.readAsBytes();
    final PdfDocument pdf;
    try {
      pdf = await PdfDocument.openData(
        original,
        passwordProvider: () async => null,
        sourceName: 'memory:annotate',
      );
    } on PdfPasswordException {
      throw const LibraryFormatException('Protected PDFs cannot be annotated.');
    }
    try {
      if (pdf.isEncrypted ||
          (pdf.permissions != null &&
              !pdf.permissions!.allowsModifyAnnotations)) {
        throw const LibraryFormatException(
          'Protected PDFs cannot be annotated.',
        );
      }
      final pageCount = pdf.pages.length;
      if (notes.any((n) => n.page > pageCount)) {
        throw const LibraryFormatException('A note refers to a missing page.');
      }
      final written = await pdf.useNativeDocumentHandle(
        (handle) => _write(handle, notes),
      );
      if (written != notes.length) {
        throw const LibraryFormatException('Notes could not be written.');
      }
      final bytes = await pdf.encodePdf(incremental: true);
      if (bytes.length <= original.length || bytes.length > maxImportBytes) {
        throw const LibraryFormatException('Annotated PDF failed checks.');
      }
      for (var i = 0; i < original.length; i++) {
        if (bytes[i] != original[i]) {
          throw const LibraryFormatException('Annotated PDF failed checks.');
        }
      }
      final check = await PdfDocument.openData(bytes);
      try {
        if (check.pages.length != pageCount) {
          throw const LibraryFormatException('Annotated PDF failed checks.');
        }
      } finally {
        await check.dispose();
      }
      return bytes;
    } finally {
      await pdf.dispose();
    }
  }

  /// Builds the annotated copy and adds it to the library under [title].
  Future<PaperDocument> saveToLibrary({
    required LibraryRepository repository,
    required PaperDocument document,
    required String title,
  }) async {
    final bytes = await build(repository: repository, document: document);
    final saved = await repository.importPdf(
      name: title,
      bytes: Stream.value(bytes),
    );
    if (document.pageCount == null) return saved;
    await repository.updateDocument(
      saved.id,
      (d) => d.copyWith(pageCount: document.pageCount),
    );
    return saved.copyWith(pageCount: document.pageCount);
  }

  /// Runs on the calling isolate while pdfrx's worker is paused.
  static int _write(int handle, List<PaperNote> notes) {
    final lib = pdfium.getPdfium(modulePath: Pdfrx.pdfiumModulePath);
    final doc = pdfium.FPDF_DOCUMENT.fromAddress(handle);
    final byPage = <int, List<PaperNote>>{};
    for (final note in notes) {
      (byPage[note.page] ??= []).add(note);
    }
    var written = 0;
    using((arena) {
      final box = arena<pdfium.FS_RECTF>();
      final quad = arena<pdfium.FS_QUADPOINTSF>();
      for (final entry in byPage.entries) {
        final page = lib.FPDF_LoadPage(doc, entry.key - 1);
        if (page == nullptr) continue;
        try {
          // Notes store coordinates relative to the page's visible box, as
          // pdfrx reports text positions; annotations need user space.
          if (lib.FPDF_GetPageBoundingBox(page, box) == 0) continue;
          final bounds = (
            left: box.ref.left,
            top: box.ref.top,
            right: box.ref.right,
            bottom: box.ref.bottom,
          );
          final rotation = lib.FPDFPage_GetRotation(page);
          var stickyIndex = 0;
          for (final note in entry.value) {
            final highlight = note.boxes.isNotEmpty;
            final drawing = note.isDrawing;
            final annot = lib.FPDFPage_CreateAnnot(
              page,
              highlight
                  ? pdfium.FPDF_ANNOT_HIGHLIGHT
                  : drawing
                  ? pdfium.FPDF_ANNOT_INK
                  : pdfium.FPDF_ANNOT_TEXT,
            );
            if (annot == nullptr) continue;
            try {
              var ok = true;
              if (highlight) {
                for (final b in mergeLineBoxes(note.boxes)) {
                  final l = bounds.left + b.left, r = bounds.left + b.right;
                  final t = bounds.bottom + b.top,
                      bt = bounds.bottom + b.bottom;
                  quad.ref
                    ..x1 = l
                    ..y1 = t
                    ..x2 = r
                    ..y2 = t
                    ..x3 = l
                    ..y3 = bt
                    ..x4 = r
                    ..y4 = bt;
                  ok &= lib.FPDFAnnot_AppendAttachmentPoints(annot, quad) != 0;
                }
                final rect = highlightRect(note.boxes);
                box.ref
                  ..left = bounds.left + rect.left
                  ..top = bounds.bottom + rect.top
                  ..right = bounds.left + rect.right
                  ..bottom = bounds.bottom + rect.bottom;
              } else if (drawing) {
                for (final stroke in note.ink) {
                  final points = arena<pdfium.FS_POINTF>(stroke.length);
                  for (var i = 0; i < stroke.length; i++) {
                    points[i]
                      ..x = bounds.left + stroke.points[2 * i]
                      ..y = bounds.bottom + stroke.points[2 * i + 1];
                  }
                  ok &=
                      lib.FPDFAnnot_AddInkStroke(
                        annot,
                        points,
                        stroke.length,
                      ) >=
                      0;
                }
                ok &= lib.FPDFAnnot_SetBorder(annot, 0, 0, penWidth) != 0;
                final rect = inkRect(note.ink, penWidth);
                box.ref
                  ..left = bounds.left + rect.left
                  ..top = bounds.bottom + rect.top
                  ..right = bounds.left + rect.right
                  ..bottom = bounds.bottom + rect.bottom;
              } else {
                final rect = stickyNoteRect(bounds, rotation, stickyIndex++);
                box.ref
                  ..left = rect.left
                  ..top = rect.top
                  ..right = rect.right
                  ..bottom = rect.bottom;
              }
              ok &= lib.FPDFAnnot_SetRect(annot, box) != 0;
              ok &=
                  lib.FPDFAnnot_SetColor(
                    annot,
                    pdfium.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
                    note.displayColor >> 16 & 0xFF,
                    note.displayColor >> 8 & 0xFF,
                    note.displayColor & 0xFF,
                    255,
                  ) !=
                  0;
              ok &=
                  lib.FPDFAnnot_SetFlags(
                    annot,
                    pdfium.FPDF_ANNOT_FLAG_PRINT |
                        (highlight
                            ? 0
                            : pdfium.FPDF_ANNOT_FLAG_NOZOOM |
                                  pdfium.FPDF_ANNOT_FLAG_NOROTATE),
                  ) !=
                  0;
              final date = pdfDate(note.createdAt);
              for (final (key, value) in [
                ('Contents', note.text),
                ('NM', 'cave-paper-${note.id}'),
                ('CreationDate', date),
                ('M', date),
              ]) {
                ok &=
                    lib.FPDFAnnot_SetStringValue(
                      annot,
                      key.toNativeUtf8(allocator: arena).cast(),
                      _wide(value, arena),
                    ) !=
                    0;
              }
              if (ok) written++;
            } finally {
              lib.FPDFPage_CloseAnnot(annot);
            }
          }
        } finally {
          lib.FPDF_ClosePage(page);
        }
      }
    });
    return written;
  }

  static Pointer<pdfium.FPDF_WCHAR> _wide(String value, Arena arena) {
    final units = value.codeUnits;
    final buffer = arena<Uint16>(units.length + 1);
    buffer.asTypedList(units.length + 1)
      ..setAll(0, units)
      ..[units.length] = 0;
    return buffer.cast();
  }
}

typedef PdfBounds = ({double left, double top, double right, double bottom});

/// The smallest box (page coordinates, top >= bottom) around [boxes].
PdfBounds highlightRect(List<HighlightBox> boxes) {
  var left = boxes.first.left, right = boxes.first.right;
  var top = boxes.first.top, bottom = boxes.first.bottom;
  for (final b in boxes.skip(1)) {
    if (b.left < left) left = b.left;
    if (b.right > right) right = b.right;
    if (b.top > top) top = b.top;
    if (b.bottom < bottom) bottom = b.bottom;
  }
  return (left: left, top: top, right: right, bottom: bottom);
}

/// The box around every point of [ink], widened by the line width.
PdfBounds inkRect(List<InkStroke> ink, double width) {
  var left = double.infinity, bottom = double.infinity;
  var right = double.negativeInfinity, top = double.negativeInfinity;
  for (final stroke in ink) {
    for (var i = 0; i < stroke.points.length; i += 2) {
      final x = stroke.points[i], y = stroke.points[i + 1];
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < bottom) bottom = y;
      if (y > top) top = y;
    }
  }
  return (
    left: left - width,
    top: top + width,
    right: right + width,
    bottom: bottom - width,
  );
}

/// Joins word boxes that sit next to each other on the same line, so other
/// apps draw one even bar per line instead of a row of separate marks.
List<HighlightBox> mergeLineBoxes(List<HighlightBox> boxes) {
  final merged = <HighlightBox>[];
  for (final b in boxes) {
    final last = merged.isEmpty ? null : merged.last;
    if (last != null) {
      final overlap =
          (last.top < b.top ? last.top : b.top) -
          (last.bottom > b.bottom ? last.bottom : b.bottom);
      final height = (last.top - last.bottom) < (b.top - b.bottom)
          ? last.top - last.bottom
          : b.top - b.bottom;
      final gap = b.left > last.right
          ? b.left - last.right
          : last.left > b.right
          ? last.left - b.right
          : 0.0;
      if (overlap > height * 0.5 && gap <= height) {
        merged.last = HighlightBox(
          last.left < b.left ? last.left : b.left,
          last.top > b.top ? last.top : b.top,
          last.right > b.right ? last.right : b.right,
          last.bottom < b.bottom ? last.bottom : b.bottom,
        );
        continue;
      }
    }
    merged.add(b);
  }
  return merged;
}

/// Where the [index]th sticky note on a page goes: a column down the left edge
/// as the page is shown, whatever its [rotation] (quarter turns clockwise).
PdfBounds stickyNoteRect(PdfBounds page, int rotation, int index) {
  const size = 20.0, margin = 12.0, step = 28.0;
  final visibleHeight = rotation.isOdd
      ? page.right - page.left
      : page.top - page.bottom;
  final rows = ((visibleHeight - 2 * margin) / step).floor().clamp(1, 1000);
  // Centre of the icon in shown-page coordinates (from top-left, y down).
  final vx = margin + size / 2 + step * (index ~/ rows);
  final vy = margin + size / 2 + step * (index % rows);
  final (x, y) = switch (rotation % 4) {
    1 => (page.left + vy, page.bottom + vx),
    2 => (page.right - vx, page.bottom + vy),
    3 => (page.right - vy, page.top - vx),
    _ => (page.left + vx, page.top - vy),
  };
  const half = size / 2;
  return (left: x - half, top: y + half, right: x + half, bottom: y - half);
}

/// A PDF date string, e.g. `D:20261126093000Z`.
String pdfDate(DateTime time) {
  final t = time.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'D:${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
}
