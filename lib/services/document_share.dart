import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../data/library_repository.dart';
import '../domain/library.dart';

/// Explicit export only: never embeds notes, decrypts, or changes the PDF.
class DocumentShare {
  DocumentShare({
    Future<ShareResult> Function(ShareParams)? share,
    Future<Directory> Function()? temporaryDirectory,
  }) : _share = share ?? SharePlus.instance.share,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Future<ShareResult> Function(ShareParams) _share;
  final Future<Directory> Function() _temporaryDirectory;
  bool _busy = false;

  static bool get supported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  Future<void> share({
    required LibraryRepository repository,
    required PaperDocument document,
    required Rect origin,
    required bool includeAnnotations,
    bool Function()? isActive,
  }) async {
    if (_busy) return;
    _busy = true;
    try {
      // Verify the imported copy still exists and belongs to this fingerprint.
      await repository.verifyDocument(document);
      if (isActive != null && !isActive()) return;
      final file = repository.documentFile(document.id);
      final title = safeName(document.title);
      final cache = await _temporaryDirectory();
      final directory = await cache.createTemp('cave-paper-share-');
      // Path-backed files ignore name overrides on some native platforms.
      // Copy by streaming into a unique cache folder, never into the library.
      final copy = await file.copy(p.join(directory.path, '$title.pdf'));
      if (isActive != null && !isActive()) {
        await directory.delete(recursive: true);
        return;
      }
      final files = <XFile>[XFile(copy.path, mimeType: 'application/pdf')];
      final names = <String>['$title.pdf'];
      if (includeAnnotations) {
        files.add(
          XFile.fromData(
            utf8.encode(
              AnnotationBundle(
                documentId: document.id,
                notes: document.notes,
                bookmarks: document.bookmarks,
              ).encode(),
            ),
            mimeType: 'application/json',
          ),
        );
        names.add('$title.paper.json');
      }
      if (isActive != null && !isActive()) {
        await directory.delete(recursive: true);
        return;
      }
      // Keep cached copies after handing off: receivers may read asynchronously.
      // A native share result is not proof of delivery. Do not claim success.
      await _share(
        ShareParams(
          files: files,
          fileNameOverrides: names,
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  static String safeName(String title) {
    var name = title
        .replaceAll(RegExp(r'[\x00-\x1f\x7f/\\:*?"<>|]'), '_')
        .trim();
    name = name.replaceAll(RegExp(r'^\.+|\.+$'), '');
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4);
    }
    if (name.isEmpty) name = 'document';
    if (RegExp(
      r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
      caseSensitive: false,
    ).hasMatch(name)) {
      name = '_$name';
    }
    // 60 runes use at most 240 UTF-8 bytes, leaving room for .paper.json.
    return String.fromCharCodes(name.runes.take(60));
  }
}
