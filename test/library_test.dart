import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/data/offline_policy.dart';
import 'package:cave_paper/domain/library.dart';

void main() {
  late Directory temp;
  late LibraryRepository repo;
  final pdf = utf8.encode('%PDF-1.7\nA synthetic repository fixture\n%%EOF\n');
  Future<PaperDocument> add([String name = 'Report.pdf', List<int>? data]) =>
      repo.importPdf(name: name, bytes: Stream.value(data ?? pdf));
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cave-paper-test-');
    repo = LibraryRepository(Directory('${temp.path}/library'));
  });
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('new library is empty and has no account dependency', () async {
    final state = await repo.load();
    expect(state.documents, isEmpty);
    expect(state.revision, 0);
  });
  test('import uses the SHA256 of exact source bytes', () async {
    final doc = await add();
    expect(doc.id, sha256.convert(pdf).toString());
    expect(await repo.documentFile(doc.id).readAsBytes(), pdf);
    await repo.verifyDocument(doc);
  });
  test('duplicate bytes do not duplicate records or notes', () async {
    final first = await add();
    await repo.updateDocument(first.id, (d) => d.copyWith(bookmarks: [2]));
    final second = await add('A different filename.pdf');
    expect(second.id, first.id);
    expect(second.bookmarks, [2]);
    expect((await repo.load()).documents.length, 1);
  });
  test('same filenames with different bytes remain distinct', () async {
    await add();
    await add(
      'Report.pdf',
      utf8.encode('%PDF-1.7\nA different document\n%%EOF'),
    );
    expect((await repo.load()).documents.length, 2);
  });
  test('missing header rejects import and keeps existing library', () async {
    await add();
    await expectLater(
      add('bad.pdf', utf8.encode('not a PDF at all')),
      throwsA(isA<LibraryFormatException>()),
    );
    expect((await repo.load()).documents.length, 1);
    expect(
      await Directory('${repo.root.path}/imports').list().toList(),
      isEmpty,
    );
  });
  test('small configured import limit stops an oversized stream', () async {
    final small = LibraryRepository(repo.root, importLimit: 16);
    await expectLater(
      small.importPdf(name: 'big.pdf', bytes: Stream.value(pdf)),
      throwsA(isA<LibraryFormatException>()),
    );
    expect((await repo.load()).documents, isEmpty);
  });
  test('interrupted source stream leaves no partial import', () async {
    Stream<List<int>> broken() async* {
      yield pdf;
      throw const FileSystemException('test interruption');
    }

    await expectLater(
      repo.importPdf(name: 'fail.pdf', bytes: broken()),
      throwsA(isA<FileSystemException>()),
    );
    expect((await repo.load()).documents, isEmpty);
    expect(
      await Directory('${repo.root.path}/imports').list().toList(),
      isEmpty,
    );
  });
  test('content alteration is detected before viewing', () async {
    final doc = await add();
    await repo.documentFile(doc.id).writeAsString('%PDF-1.7\nmodified\n%%EOF');
    await expectLater(
      repo.verifyDocument(doc),
      throwsA(isA<LibraryFormatException>()),
    );
  });
  test('reimport repairs a damaged copy and retains its evidence', () async {
    final doc = await add();
    await repo.documentFile(doc.id).writeAsString('broken');
    await add();
    await repo.verifyDocument(doc);
    expect(
      await repo
          .documentFile(doc.id)
          .parent
          .list()
          .where((f) => f.path.contains('.damaged-'))
          .length,
      1,
    );
  });
  test('mutations across two repository objects are serialized', () async {
    final doc = await add();
    final other = LibraryRepository(repo.root);
    await Future.wait([
      repo.updateDocument(
        doc.id,
        (d) => d.copyWith(bookmarks: [...d.bookmarks, 2]),
      ),
      other.updateDocument(
        doc.id,
        (d) => d.copyWith(bookmarks: [...d.bookmarks, 3]),
      ),
    ]);
    expect((await repo.load()).find(doc.id)!.bookmarks, [2, 3]);
  });
  test('failed operation does not poison later operations', () async {
    final doc = await add();
    await expectLater(
      repo.updateDocument('missing', (d) => d),
      throwsA(isA<LibraryFormatException>()),
    );
    await repo.updateDocument(doc.id, (d) => d.copyWith(title: 'Renamed.pdf'));
    expect((await repo.load()).find(doc.id)!.title, 'Renamed.pdf');
  });
  test('persisted settings and bookmark survive repository restart', () async {
    final doc = await add();
    await repo.setSettings(
      const PaperSettings(language: 'ar', appearance: Appearance.dark),
    );
    await repo.updateDocument(
      doc.id,
      (d) => d.copyWith(bookmarks: [3, 1, 3], lastPage: 3),
    );
    final reopened = await LibraryRepository(repo.root).load();
    expect(reopened.settings.language, 'ar');
    expect(reopened.settings.appearance, Appearance.dark);
    expect(reopened.find(doc.id)!.bookmarks, [1, 3]);
    expect(reopened.find(doc.id)!.lastPage, 3);
  });
  test(
    'checksum failure falls back without erasing the damaged generation',
    () async {
      final doc = await add();
      await repo.updateDocument(doc.id, (d) => d.copyWith(lastPage: 2));
      final files = await repo.root
          .list()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      await File(files.first.path).writeAsString('{broken');
      expect((await repo.load()).documents.length, 1);
      expect(repo.warning, 'recovered');
      expect(await File(files.first.path).readAsString(), '{broken');
    },
  );
  test('no valid snapshot is an error rather than an empty reset', () async {
    await add();
    await for (final file in repo.root.list()) {
      if (file.path.endsWith('.json')) {
        await File(file.path).writeAsString('broken');
      }
    }
    await expectLater(repo.load(), throwsA(isA<LibraryFormatException>()));
  });
  test('future schema is never silently opened with older metadata', () async {
    await add();
    final future = jsonEncode({'schema': 999});
    await File('${repo.root.path}/state-00000000000000000002.json')
        .writeAsString(
          jsonEncode({
            'payload': future,
            'sha256': sha256.convert(utf8.encode(future)).toString(),
          }),
        );
    await expectLater(repo.load(), throwsA(isA<LibraryFormatException>()));
  });
  test('removal touches the managed copy, not the original source', () async {
    final original = File('${temp.path}/original.pdf');
    await original.writeAsBytes(pdf);
    final doc = await repo.importPdf(
      name: 'original.pdf',
      bytes: original.openRead(),
    );
    await repo.removeDocument(doc.id);
    expect(await original.readAsBytes(), pdf);
    expect(await repo.documentFile(doc.id).exists(), false);
    expect((await repo.load()).documents, isEmpty);
    expect(
      await repo.root.list().where((f) => f.path.endsWith('.json')).length,
      1,
    );
  });
  test('path traversal IDs are refused', () {
    expect(
      () => repo.documentFile('../../original'),
      throwsA(isA<LibraryFormatException>()),
    );
    expect(LibraryRepository.sanitizeTitle('../../a\u0000.pdf'), 'a.pdf');
  });
  test('annotation export is round-trippable and retry-safe', () async {
    final doc = await add();
    final note = PaperNote(
      id: 'n-1',
      page: 1,
      text: 'A note / ملاحظة',
      createdAt: DateTime.utc(2026),
      boxes: [HighlightBox(10, 50, 100, 20)],
    );
    final bundle = AnnotationBundle.decode(
      AnnotationBundle(
        documentId: doc.id,
        notes: [note],
        bookmarks: [1],
      ).encode(),
    );
    await repo.mergeAnnotations(doc.id, bundle, pageCount: 3);
    await repo.mergeAnnotations(doc.id, bundle, pageCount: 3);
    final saved = (await repo.load()).find(doc.id)!;
    expect(saved.notes.length, 1);
    expect(saved.bookmarks, [1]);
  });
  test('cross-document note import fails without mutating notes', () async {
    final doc = await add();
    final bundle = AnnotationBundle(
      documentId: List.filled(64, 'f').join(),
      notes: [],
      bookmarks: [1],
    );
    await expectLater(
      repo.mergeAnnotations(doc.id, bundle, pageCount: 3),
      throwsA(isA<LibraryFormatException>()),
    );
    expect((await repo.load()).find(doc.id)!.bookmarks, isEmpty);
  });
  test('conflicting note IDs fail atomically', () async {
    final doc = await add();
    PaperNote note(String text) => PaperNote(
      id: 'same',
      page: 1,
      text: text,
      createdAt: DateTime.utc(2026),
    );
    await repo.mergeAnnotations(
      doc.id,
      AnnotationBundle(
        documentId: doc.id,
        notes: [note('first')],
        bookmarks: [],
      ),
      pageCount: 1,
    );
    await expectLater(
      repo.mergeAnnotations(
        doc.id,
        AnnotationBundle(
          documentId: doc.id,
          notes: [note('second')],
          bookmarks: [1],
        ),
        pageCount: 1,
      ),
      throwsA(isA<LibraryFormatException>()),
    );
    final saved = (await repo.load()).find(doc.id)!;
    expect(saved.notes.single.text, 'first');
    expect(saved.bookmarks, isEmpty);
  });
  test('out of range annotations fail', () async {
    final doc = await add();
    await expectLater(
      repo.mergeAnnotations(
        doc.id,
        AnnotationBundle(documentId: doc.id, notes: [], bookmarks: [99]),
        pageCount: 2,
      ),
      throwsA(isA<LibraryFormatException>()),
    );
  });
  test('untrusted highlight geometry is validated', () {
    for (final data in [
      [0, 1, 0, 0],
      [-1, 2, 3, 0],
      [0, 1, 3, 2],
    ]) {
      expect(
        () => HighlightBox.fromJson(data),
        throwsA(isA<LibraryFormatException>()),
      );
    }
    expect(
      () => HighlightBox(0, double.infinity, 3, 0),
      throwsA(isA<LibraryFormatException>()),
    );
  });
  test('runtime HTTP is refused even for dependencies', () {
    expect(
      () => HttpOverrides.runWithHttpOverrides(
        () => HttpClient(),
        OfflineHttpOverrides(),
      ),
      throwsA(isA<HttpException>()),
    );
  });
}
