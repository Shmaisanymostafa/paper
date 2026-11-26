// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

enum EmbeddedKind { highlight, underline, strikeout, squiggly, note, drawing }

/// A highlight, comment or drawing stored inside the PDF itself, by another
/// app or by Cave Paper's "Save copy with highlights". Read-only.
class EmbeddedAnnotation {
  const EmbeddedAnnotation({
    required this.page,
    required this.kind,
    required this.comment,
    required this.quote,
    this.color,
  });
  final int page;
  final EmbeddedKind kind;

  /// The annotation's own comment (PDF `Contents`), possibly empty.
  final String comment;

  /// For highlights and other text marks: the text they cover.
  final String quote;

  /// 0xRRGGBB, when the PDF gives one.
  final int? color;

  /// What to show in a list: the comment, else the marked text.
  String get label => comment.trim().isNotEmpty ? comment : quote;
}

/// Reads the annotations people care about (text marks, notes, drawings) from
/// an open document. Links, form widgets and pop-ups are skipped. Bounded so a
/// huge or hostile PDF cannot stall the reader.
class PdfAnnotationReader {
  static const maxPages = 500, maxResults = 2000, maxText = 2000;

  static const _kinds = {
    pdfium.FPDF_ANNOT_HIGHLIGHT: EmbeddedKind.highlight,
    pdfium.FPDF_ANNOT_UNDERLINE: EmbeddedKind.underline,
    pdfium.FPDF_ANNOT_STRIKEOUT: EmbeddedKind.strikeout,
    pdfium.FPDF_ANNOT_SQUIGGLY: EmbeddedKind.squiggly,
    pdfium.FPDF_ANNOT_TEXT: EmbeddedKind.note,
    pdfium.FPDF_ANNOT_FREETEXT: EmbeddedKind.note,
    pdfium.FPDF_ANNOT_INK: EmbeddedKind.drawing,
  };

  Future<List<EmbeddedAnnotation>> read(PdfDocument document) =>
      document.useNativeDocumentHandle(_read);

  /// Reads from a separate copy of [path]; if it cannot be opened without a
  /// password, reads [fallback] (an already open document) instead.
  Future<List<EmbeddedAnnotation>> readFile(
    String path, {
    PdfDocument? fallback,
  }) async {
    PdfDocument? own;
    try {
      own = await PdfDocument.openFile(
        path,
        passwordProvider: () async => null,
      );
    } on PdfPasswordException {
      own = null;
    }
    if (own == null) {
      return fallback == null ? const [] : read(fallback);
    }
    try {
      return await read(own);
    } finally {
      await own.dispose();
    }
  }

  static List<EmbeddedAnnotation> _read(int handle) {
    final lib = pdfium.getPdfium(modulePath: Pdfrx.pdfiumModulePath);
    final doc = pdfium.FPDF_DOCUMENT.fromAddress(handle);
    final results = <EmbeddedAnnotation>[];
    using((arena) {
      final quad = arena<pdfium.FS_QUADPOINTSF>();
      final r = arena<UnsignedInt>(), g = arena<UnsignedInt>();
      final b = arena<UnsignedInt>(), a = arena<UnsignedInt>();
      final textBuffer = arena<UnsignedShort>(maxText + 1);
      final keyContents = 'Contents'
          .toNativeUtf8(allocator: arena)
          .cast<Char>();
      final pages = lib.FPDF_GetPageCount(doc).clamp(0, maxPages);
      for (var p = 0; p < pages && results.length < maxResults; p++) {
        final page = lib.FPDF_LoadPage(doc, p);
        if (page == nullptr) continue;
        pdfium.FPDF_TEXTPAGE? textPage;
        try {
          final count = lib.FPDFPage_GetAnnotCount(page);
          for (var i = 0; i < count && results.length < maxResults; i++) {
            final annot = lib.FPDFPage_GetAnnot(page, i);
            if (annot == nullptr) continue;
            try {
              final kind = _kinds[lib.FPDFAnnot_GetSubtype(annot)];
              if (kind == null) continue;
              final comment = _string(lib, annot, keyContents, arena);
              var quote = '';
              if (kind != EmbeddedKind.note && kind != EmbeddedKind.drawing) {
                textPage ??= lib.FPDFText_LoadPage(page);
                final parts = <String>[];
                final quads = lib.FPDFAnnot_CountAttachmentPoints(annot);
                for (var q = 0; q < quads && q < 200; q++) {
                  if (lib.FPDFAnnot_GetAttachmentPoints(annot, q, quad) == 0) {
                    continue;
                  }
                  final qr = quad.ref;
                  double min4(double a, double b, double c, double d) =>
                      [a, b, c, d].reduce((x, y) => x < y ? x : y);
                  double max4(double a, double b, double c, double d) =>
                      [a, b, c, d].reduce((x, y) => x > y ? x : y);
                  final n = lib.FPDFText_GetBoundedText(
                    textPage,
                    min4(qr.x1, qr.x2, qr.x3, qr.x4),
                    max4(qr.y1, qr.y2, qr.y3, qr.y4),
                    max4(qr.x1, qr.x2, qr.x3, qr.x4),
                    min4(qr.y1, qr.y2, qr.y3, qr.y4),
                    textBuffer,
                    maxText,
                  );
                  if (n > 0) {
                    parts.add(
                      String.fromCharCodes(
                        textBuffer
                            .cast<Uint16>()
                            .asTypedList(n)
                            .takeWhile((c) => c != 0),
                      ).trim(),
                    );
                  }
                }
                quote = parts.where((t) => t.isNotEmpty).join(' ');
                if (quote.length > maxText) quote = quote.substring(0, maxText);
              }
              if (comment.trim().isEmpty &&
                  quote.isEmpty &&
                  kind != EmbeddedKind.drawing) {
                continue;
              }
              final hasColor =
                  lib.FPDFAnnot_GetColor(
                    annot,
                    pdfium.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
                    r,
                    g,
                    b,
                    a,
                  ) !=
                  0;
              results.add(
                EmbeddedAnnotation(
                  page: p + 1,
                  kind: kind,
                  comment: comment,
                  quote: quote,
                  color: hasColor
                      ? (r.value & 0xFF) << 16 |
                            (g.value & 0xFF) << 8 |
                            (b.value & 0xFF)
                      : null,
                ),
              );
            } finally {
              lib.FPDFPage_CloseAnnot(annot);
            }
          }
        } finally {
          if (textPage != null) lib.FPDFText_ClosePage(textPage);
          lib.FPDF_ClosePage(page);
        }
      }
    });
    return results;
  }

  static String _string(
    pdfium.PDFium lib,
    pdfium.FPDF_ANNOTATION annot,
    Pointer<Char> key,
    Arena arena,
  ) {
    final bytes = lib.FPDFAnnot_GetStringValue(annot, key, nullptr, 0);
    if (bytes <= 2) return '';
    final capped = bytes > (maxText + 1) * 2 ? (maxText + 1) * 2 : bytes;
    final buffer = arena<Uint16>(capped ~/ 2 + 1);
    lib.FPDFAnnot_GetStringValue(annot, key, buffer.cast(), capped);
    final units = buffer.asTypedList(capped ~/ 2).takeWhile((c) => c != 0);
    return String.fromCharCodes(units.take(maxText));
  }
}
