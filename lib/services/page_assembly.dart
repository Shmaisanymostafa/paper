// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../data/library_repository.dart';
import '../domain/library.dart';
import '../domain/page_edit.dart';

/// Writes a [PageEditPlan] as a new PDF and adds it to the library. The source
/// documents are only read; their files and library entries never change.
/// Like page copy, document-level forms, signatures and outlines are not
/// promised to survive, and Cave Paper's own notes stay with the original.
class PageAssembly {
  static const maxSourceBytes = 64 * 1024 * 1024;

  Future<Uint8List> build({
    required LibraryRepository repository,
    required PageEditPlan plan,
  }) async {
    if (plan.isEmpty) {
      throw const LibraryFormatException('Select at least one page.');
    }
    final library = await repository.load();
    final sources = <String, PdfDocument>{};
    try {
      for (final id in plan.documentIds) {
        final document = library.find(id);
        if (document == null) {
          throw const LibraryFormatException('Document no longer exists.');
        }
        if (document.byteLength > maxSourceBytes) {
          throw const LibraryFormatException('PDF is too large to edit.');
        }
        await repository.verifyDocument(document);
        final PdfDocument pdf;
        try {
          pdf = await PdfDocument.openFile(
            repository.documentFile(id).path,
            passwordProvider: () async => null,
          );
        } on PdfPasswordException {
          throw const LibraryFormatException(
            'Protected PDFs cannot be edited.',
          );
        }
        sources[id] = pdf;
        if (pdf.isEncrypted ||
            (pdf.permissions != null &&
                !pdf.permissions!.allowsDocumentAssembly)) {
          throw const LibraryFormatException(
            'Protected PDFs cannot be edited.',
          );
        }
      }
      final output = await PdfDocument.createNew(sourceName: 'memory:edit');
      try {
        output.pages = [
          for (final page in plan.pages) _page(sources[page.documentId]!, page),
        ];
        final bytes = await output.encodePdf();
        if (bytes.isEmpty || bytes.length > maxImportBytes) {
          throw const LibraryFormatException('Edited PDF is too large.');
        }
        final check = await PdfDocument.openData(bytes);
        try {
          if (check.pages.length != plan.length) {
            throw const LibraryFormatException('Edited PDF failed checks.');
          }
        } finally {
          await check.dispose();
        }
        return bytes;
      } finally {
        await output.dispose();
      }
    } finally {
      for (final pdf in sources.values) {
        await pdf.dispose();
      }
    }
  }

  PdfPage _page(PdfDocument source, EditedPage page) {
    if (page.page < 1 || page.page > source.pages.length) {
      throw const LibraryFormatException('Invalid page selection.');
    }
    final original = source.pages[page.page - 1];
    return page.turns == 0
        ? original
        : original.rotatedBy(PdfPageRotation.values[page.turns]);
  }

  /// Builds the PDF and adds it to the library under [title].
  Future<PaperDocument> saveToLibrary({
    required LibraryRepository repository,
    required PageEditPlan plan,
    required String title,
  }) async {
    final bytes = await build(repository: repository, plan: plan);
    final document = await repository.importPdf(
      name: title,
      bytes: Stream.value(bytes),
    );
    await repository.updateDocument(
      document.id,
      (d) => d.copyWith(pageCount: plan.length),
    );
    return document.copyWith(pageCount: plan.length);
  }
}
