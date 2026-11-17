import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/services/document_share.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  late Directory temp;
  late LibraryRepository repo;
  late PaperDocument doc;
  final pdf = utf8.encode('%PDF-1.7\nSynthetic share test\n%%EOF');
  const origin = Rect.fromLTWH(0, 0, 100, 100);
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('paper-share-test-');
    repo = LibraryRepository(temp);
    doc = await repo.importPdf(
      name: 'Private report.pdf',
      bytes: Stream.value(pdf),
    );
    doc = doc.copyWith(
      notes: [
        PaperNote(
          id: 'private-note',
          page: 1,
          text: 'Private extracted text',
          createdAt: DateTime.utc(2026),
          boxes: [HighlightBox(1, 10, 10, 1)],
        ),
      ],
      bookmarks: [1],
    );
  });
  tearDown(() => temp.delete(recursive: true));

  test(
    'exports exact original bytes and fingerprint-bound separate notes',
    () async {
      final exporter = DocumentShare(
        temporaryDirectory: () async => temp,
        share: (params) async {
          expect(params.files, hasLength(2));
          expect(await params.files![0].readAsBytes(), pdf);
          expect(params.files![0].path.endsWith('/Private report.pdf'), isTrue);
          expect(params.files![0].path, isNot(repo.documentFile(doc.id).path));
          final bundle = AnnotationBundle.decode(
            await params.files![1].readAsString(),
          );
          expect(bundle.documentId, doc.id);
          expect(bundle.notes.single.text, 'Private extracted text');
          expect(bundle.bookmarks, [1]);
          expect(params.fileNameOverrides, [
            'Private report.pdf',
            'Private report.paper.json',
          ]);
          expect(params.sharePositionOrigin, origin);
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );
      await exporter.share(
        repository: repo,
        document: doc,
        origin: origin,
        includeAnnotations: true,
      );
      await repo.verifyDocument(doc);
      expect(await repo.documentFile(doc.id).readAsBytes(), pdf);
    },
  );

  test('PDF-only export does not disclose notes', () async {
    final exporter = DocumentShare(
      temporaryDirectory: () async => temp,
      share: (params) async {
        expect(params.files, hasLength(1));
        expect(params.files!.single.mimeType, 'application/pdf');
        expect(params.text, isNull);
        return const ShareResult('', ShareResultStatus.unavailable);
      },
    );
    await exporter.share(
      repository: repo,
      document: doc,
      origin: origin,
      includeAnnotations: false,
    );
  });

  test('changed or missing document never reaches native share', () async {
    var calls = 0;
    final exporter = DocumentShare(
      temporaryDirectory: () async => temp,
      share: (_) async {
        calls++;
        return const ShareResult('', ShareResultStatus.success);
      },
    );
    await repo.documentFile(doc.id).writeAsString('changed');
    await expectLater(
      exporter.share(
        repository: repo,
        document: doc,
        origin: origin,
        includeAnnotations: true,
      ),
      throwsA(isA<LibraryFormatException>()),
    );
    await repo.documentFile(doc.id).delete();
    await expectLater(
      exporter.share(
        repository: repo,
        document: doc,
        origin: origin,
        includeAnnotations: true,
      ),
      throwsA(isA<LibraryFormatException>()),
    );
    expect(calls, 0);
  });

  test('repeated calls coalesce while sharing, then allow retry', () async {
    var calls = 0;
    final pending = Completer<ShareResult>();
    final exporter = DocumentShare(
      temporaryDirectory: () async => temp,
      share: (_) {
        calls++;
        return pending.future;
      },
    );
    final first = exporter.share(
      repository: repo,
      document: doc,
      origin: origin,
      includeAnnotations: true,
    );
    await exporter.share(
      repository: repo,
      document: doc,
      origin: origin,
      includeAnnotations: true,
    );
    pending.complete(const ShareResult('', ShareResultStatus.dismissed));
    await first;
    expect(calls, 1);
    await exporter.share(
      repository: repo,
      document: doc,
      origin: origin,
      includeAnnotations: false,
    );
    expect(calls, 2);
  });

  test('failure releases busy guard for another attempt', () async {
    var calls = 0;
    final exporter = DocumentShare(
      temporaryDirectory: () async => temp,
      share: (_) async {
        calls++;
        throw StateError('native failure');
      },
    );
    for (var i = 0; i < 2; i++) {
      await expectLater(
        exporter.share(
          repository: repo,
          document: doc,
          origin: origin,
          includeAnnotations: false,
        ),
        throwsStateError,
      );
    }
    expect(calls, 2);
  });

  test('navigation during asynchronous preparation cancels handoff', () async {
    var active = true;
    var calls = 0;
    final exporter = DocumentShare(
      temporaryDirectory: () async {
        active = false;
        return temp;
      },
      share: (_) async {
        calls++;
        return const ShareResult('', ShareResultStatus.success);
      },
    );
    await exporter.share(
      repository: repo,
      document: doc,
      origin: origin,
      includeAnnotations: true,
      isActive: () => active,
    );
    expect(calls, 0);
    expect(
      await temp
          .list()
          .where((f) => f.path.contains('cave-paper-share-'))
          .toList(),
      isEmpty,
    );
  });

  test('closed reader never reaches native share', () async {
    var calls = 0;
    final exporter = DocumentShare(
      temporaryDirectory: () async => temp,
      share: (_) async {
        calls++;
        return const ShareResult('', ShareResultStatus.success);
      },
    );
    await exporter.share(
      repository: repo,
      document: doc,
      origin: origin,
      includeAnnotations: true,
      isActive: () => false,
    );
    expect(calls, 0);
  });

  test(
    'filenames reject paths and controls, preserve Arabic, bound length',
    () {
      expect(DocumentShare.safeName('../my:report.pdf'), '_my_report');
      expect(DocumentShare.safeName('تقرير.pdf'), 'تقرير');
      expect(DocumentShare.safeName('...'), 'document');
      expect(DocumentShare.safeName('a' * 200).length, 60);
      expect(DocumentShare.safeName('a\nb.pdf'), 'a_b');
      expect(DocumentShare.safeName('CON.pdf'), '_CON');
      expect(
        utf8.encode('${DocumentShare.safeName('😀' * 80)}.paper.json').length,
        lessThan(256),
      );
    },
  );
}
