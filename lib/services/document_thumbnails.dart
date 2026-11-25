// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../data/library_repository.dart';
import '../domain/library.dart';

/// First-page previews for the library, rendered once from the managed copy
/// and kept as small PNGs in the library's `thumbnails` folder. Password
/// protected or unreadable PDFs get no preview (the caller shows the icon).
/// Renders run one at a time so a large library never opens many PDFs at once.
class DocumentThumbnails {
  DocumentThumbnails(this.repository);
  final LibraryRepository repository;
  final _cache = <String, Future<File?>>{};
  Future<void> _queue = Future<void>.value();

  static const width = 240.0;

  File fileFor(String id) =>
      File(p.join(repository.root.path, 'thumbnails', '$id.png'));

  Future<File?> load(PaperDocument document) =>
      _cache.putIfAbsent(document.id, () => _load(document));

  /// Drops the in-memory entry after the repository removed the document.
  void forget(String id) => _cache.remove(id);

  Future<File?> _load(PaperDocument document) async {
    final file = fileFor(document.id);
    if (await file.exists()) return file;
    final run = _queue.then((_) => _render(document, file));
    _queue = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<File?> _render(PaperDocument document, File file) async {
    PdfDocument? pdf;
    try {
      await pdfrxFlutterInitialize();
      // No password provider: protected PDFs fail here and keep the icon.
      pdf = await PdfDocument.openFile(
        repository.documentFile(document.id).path,
      );
      if (pdf.pages.isEmpty) return null;
      final page = pdf.pages.first;
      if (page.width <= 0 || page.height <= 0) return null;
      final height = (width * page.height / page.width).clamp(60.0, 480.0);
      final rendered = await page.render(
        fullWidth: width,
        fullHeight: height,
        backgroundColor: 0xFFFFFFFF,
      );
      if (rendered == null) return null;
      final List<int> png;
      try {
        final image = await rendered.createImage();
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) return null;
          png = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        } finally {
          image.dispose();
        }
      } finally {
        rendered.dispose();
      }
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.part');
      await temp.writeAsBytes(png, flush: true);
      await temp.rename(file.path);
      return file;
    } catch (_) {
      return null;
    } finally {
      await pdf?.dispose();
    }
  }
}
