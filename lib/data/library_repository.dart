import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../domain/library.dart';

class LibraryRepository {
  LibraryRepository(this.root, {this.importLimit = maxImportBytes}) {
    if (importLimit < 8 || importLimit > maxImportBytes) {
      throw ArgumentError('Invalid import limit.');
    }
  }
  final Directory root;
  final int importLimit;
  static final Map<String, Future<void>> _queues = {};
  String? warning;
  static final _generationPattern = RegExp(r'^state-([0-9]{20})\.json$');

  Future<T> _locked<T>(Future<T> Function() operation) {
    final queueKey = p.normalize(p.absolute(root.path));
    final run = (_queues[queueKey] ?? Future<void>.value()).then((_) async {
      await root.create(recursive: true);
      final lock = await File(p.join(root.path, '.lock')).open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.blockingExclusive);
        return await operation();
      } finally {
        await lock.close();
      }
    });
    _queues[queueKey] = run.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return run;
  }

  Future<PaperLibrary> load() => _locked(_read);

  Future<List<File>> _generations() async {
    if (!await root.exists()) return [];
    final result = <File>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is File && _generationPattern.hasMatch(p.basename(entry.path))) result.add(entry);
    }
    result.sort((a, b) => b.path.compareTo(a.path));
    return result;
  }

  Future<PaperLibrary> _read() async {
    final files = await _generations();
    if (files.isEmpty) return PaperLibrary();
    for (var i = 0; i < files.length; i++) {
      try {
        if (await files[i].length() > 32 * 1024 * 1024) continue;
        final envelope = jsonDecode(await files[i].readAsString()) as Map<String, dynamic>;
        final payload = envelope['payload'] as String;
        if (sha256.convert(utf8.encode(payload)).toString() != envelope['sha256']) continue;
        final state = PaperLibrary.fromJson(jsonDecode(payload) as Map<String, dynamic>);
        if (i > 0) warning = 'recovered';
        return state;
      } on FormatException {
        continue;
      } on LibraryFormatException catch (e) {
        if (e.message.startsWith('Unsupported library')) rethrow;
      } on TypeError {
        continue;
      }
    }
    throw const LibraryFormatException('No valid library snapshot. Preserve the data folder for recovery.');
  }

  Future<PaperLibrary> _write(PaperLibrary candidate, {bool forgetHistory = false}) async {
    final files = await _generations();
    final maxRevision = files.isEmpty ? 0 : int.parse(
      _generationPattern.firstMatch(p.basename(files.first.path))!.group(1)!);
    final next = candidate.copyWith(revision: maxRevision + 1);
    final payload = jsonEncode(next.toJson());
    final encoded = jsonEncode({'sha256': sha256.convert(utf8.encode(payload)).toString(), 'payload': payload});
    if (utf8.encode(encoded).length > 32 * 1024 * 1024) {
      throw const LibraryFormatException('Library metadata is full. Export notes before adding more.');
    }
    final temp = File(p.join(root.path, '.state-${_uniqueId()}.tmp'));
    try {
      await temp.writeAsString(encoded, flush: true);
      await temp.rename(p.join(root.path, 'state-${next.revision.toString().padLeft(20, '0')}.json'));
    } finally {
      if (await temp.exists()) await temp.delete();
    }
    try {
      for (final stale in files.skip(forgetHistory ? 0 : 2)) { await stale.delete(); }
    } on FileSystemException { warning = 'cleanup'; }
    return next;
  }

  Future<PaperLibrary> _mutate(PaperLibrary Function(PaperLibrary) change) =>
      _locked(() async => _write(change(await _read())));

  File documentFile(String id) {
    if (!documentIdPattern.hasMatch(id)) throw const LibraryFormatException('Invalid document ID.');
    return File(p.join(root.path, 'documents', '$id.pdf'));
  }

  Future<void> verifyDocument(PaperDocument document) async {
    final file = documentFile(document.id);
    if (!await file.exists() || await file.length() != document.byteLength ||
        (await sha256.bind(file.openRead()).first).toString() != document.id) {
      throw const LibraryFormatException('PDF copy is missing or changed. Import your original again.');
    }
  }

  Future<PaperDocument> importPdf({required String name, required Stream<List<int>> bytes}) async {
    await root.create(recursive: true);
    final staging = Directory(p.join(root.path, 'imports'));
    await staging.create(recursive: true);
    final temp = File(p.join(staging.path, '${_uniqueId()}.part'));
    IOSink? sink;
    try {
      sink = temp.openWrite(mode: FileMode.writeOnly);
      var length = 0;
      final header = BytesBuilder(copy: false);
      await for (final chunk in bytes) {
        length += chunk.length;
        if (length > importLimit) throw const LibraryFormatException('PDF exceeds 200 MiB.');
        if (header.length < 1024) header.add(chunk.take(1024 - header.length).toList());
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (length < 8 || !latin1.decode(header.toBytes()).contains('%PDF-')) {
        throw const LibraryFormatException('This file does not have a PDF header.');
      }
      final id = (await sha256.bind(temp.openRead()).first).toString();
      return await _locked(() async {
        final state = await _read();
        final previous = state.find(id);
        final doc = previous ?? PaperDocument(id: id, title: sanitizeTitle(name),
          byteLength: length, importedAt: DateTime.now().toUtc());
        final file = documentFile(id);
        await file.parent.create(recursive: true);
        if (await file.exists()) {
          final correct = await file.length() == length &&
              (await sha256.bind(file.openRead()).first).toString() == id;
          if (!correct) {
            await file.rename('${file.path}.damaged-${_uniqueId()}');
            await temp.rename(file.path);
          }
        } else { await temp.rename(file.path); }
        if (previous == null) await _write(state.copyWith(documents: [...state.documents, doc]));
        return doc;
      });
    } finally {
      await sink?.close();
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<PaperLibrary> updateDocument(String id, PaperDocument Function(PaperDocument) change) => _mutate((state) {
    final previous = state.find(id);
    if (previous == null) throw const LibraryFormatException('Document no longer exists.');
    final next = change(previous);
    if (next.id != previous.id || next.byteLength != previous.byteLength) {
      throw const LibraryFormatException('Document identity cannot be changed.');
    }
    return state.copyWith(documents: [for (final doc in state.documents) if (doc.id == id) next else doc]);
  });

  Future<PaperLibrary> setSettings(PaperSettings settings) =>
      _mutate((state) => state.copyWith(settings: settings));

  Future<PaperLibrary> removeDocument(String id) => _locked(() async {
    final state = await _read();
    if (state.find(id) == null) return state;
    final next = await _write(state.copyWith(documents: state.documents.where((d) => d.id != id).toList()),
      forgetHistory: true);
    try {
      final file = documentFile(id);
      if (await file.exists()) await file.delete();
    } on FileSystemException { warning = 'cleanup'; }
    return next;
  });

  Future<PaperLibrary> mergeAnnotations(String id, AnnotationBundle incoming,
    {required int pageCount}) => updateDocument(id, (doc) {
    if (incoming.documentId != id) throw const LibraryFormatException('Notes belong to a different PDF.');
    if (incoming.notes.any((n) => n.page > pageCount) ||
        incoming.bookmarks.any((page) => page > pageCount)) {
      throw const LibraryFormatException('Annotations refer to a missing page.');
    }
    final notes = {for (final note in doc.notes) note.id: note};
    for (final note in incoming.notes) {
      final existing = notes[note.id];
      if (existing != null && jsonEncode(existing.toJson()) != jsonEncode(note.toJson())) {
        throw const LibraryFormatException('A note ID conflicts. Existing notes were preserved.');
      }
      notes[note.id] = note;
    }
    return doc.copyWith(notes: notes.values.toList(), bookmarks: [...doc.bookmarks, ...incoming.bookmarks]);
  });

  static String sanitizeTitle(String name) {
    final text = p.basename(name.replaceAll('\\', '/')).replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim();
    if (text.isEmpty) return 'Document.pdf';
    return text.length > 240 ? text.substring(0, 240) : text;
  }
}

String _uniqueId() {
  final random = Random.secure();
  final suffix = List.generate(12, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
}
