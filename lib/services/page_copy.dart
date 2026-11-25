// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:typed_data';
import 'dart:io';

import 'exclusive_pdf_save.dart';

import 'package:pdfrx/pdfrx.dart';

import '../data/library_repository.dart';
import '../domain/library.dart';

/// Offline page-copy foundation, not an in-place editor or redaction tool.
/// Returns a new PDF for explicit Save As/import by a future UI. No source or
/// library metadata is changed. Document-level forms, signatures, outlines and
/// app-local annotations are not promised to survive page assembly.
class PageCopy {
  static const maxBytes = 64 * 1024 * 1024;
  static const maxPages = 1000;

  static List<int> validateSelection(Iterable<int> pages, int pageCount) {
    final result = <int>[];
    for (final page in pages) {
      if (result.length >= maxPages || page < 1 || page > pageCount) {
        throw const LibraryFormatException('Invalid page selection.');
      }
      result.add(page);
    }
    if (result.isEmpty) {
      throw const LibraryFormatException('Select at least one page.');
    }
    return List.unmodifiable(result);
  }

  static Future<void> saveNewFile({
    required String path,
    required Uint8List bytes,
    required Directory libraryRoot,
  }) async {
    if (bytes.length > maxBytes) {
      throw const LibraryFormatException('Page copy exceeds size limits.');
    }
    await ExclusivePdfSave.save(
      path: path,
      bytes: bytes,
      libraryRoot: libraryRoot,
    );
  }

  Future<Uint8List> create({
    required LibraryRepository repository,
    required PaperDocument document,
    required Iterable<int> pages,
    int clockwiseQuarterTurns = 0,
  }) async {
    if (clockwiseQuarterTurns < 0 || clockwiseQuarterTurns > 3) {
      throw const LibraryFormatException('Invalid page rotation.');
    }
    // Snapshot the request before asynchronous work; cap lazy/unbounded inputs.
    final selection = validateSelection(pages, 0x7fffffff);
    if (document.byteLength > maxBytes) {
      throw const LibraryFormatException('PDF is too large for page copying.');
    }
    await repository.verifyDocument(document);
    final source = await PdfDocument.openFile(
      repository.documentFile(document.id).path,
      passwordProvider: () async => null,
    );
    try {
      if (source.isEncrypted ||
          (source.permissions != null &&
              !source.permissions!.allowsDocumentAssembly)) {
        throw const LibraryFormatException('Protected PDFs cannot be copied.');
      }
      validateSelection(selection, source.pages.length);
      final output = await PdfDocument.createNew(
        sourceName: 'memory:page-copy',
      );
      try {
        output.pages = [
          for (final page in selection)
            source.pages[page - 1].rotatedBy(
              PdfPageRotation.values[clockwiseQuarterTurns],
            ),
        ];
        final bytes = await output.encodePdf();
        if (bytes.isEmpty || bytes.length > maxBytes) {
          throw const LibraryFormatException('Page copy exceeds size limits.');
        }
        // Validate encoded output before offering it to any saving workflow.
        final check = await PdfDocument.openData(bytes);
        try {
          if (check.pages.length != selection.length) {
            throw const LibraryFormatException('Page copy validation failed.');
          }
        } finally {
          await check.dispose();
        }
        await repository.verifyDocument(document);
        return bytes;
      } finally {
        await output.dispose();
      }
    } finally {
      await source.dispose();
    }
  }
}
