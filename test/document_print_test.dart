import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/services/document_print.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late LibraryRepository repo;
  late PaperDocument doc;
  final pdf = utf8.encode('%PDF-1.7\nSynthetic print fixture\n%%EOF');
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('paper-print-test-');
    repo = LibraryRepository(temp);
    doc = await repo.importPdf(name: 'Sample.pdf', bytes: Stream.value(pdf));
  });
  tearDown(() => temp.delete(recursive: true));

  test(
    'passes exact original bytes and title without modifying source',
    () async {
      var calls = 0;
      final printer = DocumentPrint(
        print: (bytes, title, format) async {
          calls++;
          expect(bytes, pdf);
          expect(title, 'Sample.pdf');
          expect(format.width, 842);
          expect(format.height, 595);
          return false; // Native cancellation.
        },
      );
      await printer.print(
        repository: repo,
        document: doc,
        pageWidth: 842,
        pageHeight: 595,
        uniformPages: true,
        encrypted: false,
        allowsPrinting: true,
      );
      expect(calls, 1);
      await repo.verifyDocument(doc);
    },
  );

  test('never hands encrypted or print-restricted document to OS', () async {
    var calls = 0;
    final printer = DocumentPrint(
      print: (_, _, _) async {
        calls++;
        return true;
      },
    );
    for (final flags in [(true, true), (false, false), (true, false)]) {
      await expectLater(
        printer.print(
          repository: repo,
          document: doc,
          pageWidth: 842,
          pageHeight: 595,
          uniformPages: true,
          encrypted: flags.$1,
          allowsPrinting: flags.$2,
        ),
        throwsA(isA<DocumentPrintException>()),
      );
    }
    expect(calls, 0);
  });

  test('changed and missing files never reach printing', () async {
    var calls = 0;
    final printer = DocumentPrint(
      print: (_, _, _) async {
        calls++;
        return true;
      },
    );
    await repo.documentFile(doc.id).writeAsBytes(utf8.encode('x' * pdf.length));
    await expectLater(
      printer.print(
        repository: repo,
        document: doc,
        pageWidth: 842,
        pageHeight: 595,
        uniformPages: true,
        encrypted: false,
        allowsPrinting: true,
      ),
      throwsA(isA<DocumentPrintException>()),
    );
    await repo.documentFile(doc.id).delete();
    await expectLater(
      printer.print(
        repository: repo,
        document: doc,
        pageWidth: 842,
        pageHeight: 595,
        uniformPages: true,
        encrypted: false,
        allowsPrinting: true,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(calls, 0);
  });

  test('oversized file is refused before allocating or printing', () async {
    final handle = await repo.documentFile(doc.id).open(mode: FileMode.write);
    await handle.truncate(DocumentPrint.maxPrintBytes + 1);
    await handle.close();
    var calls = 0;
    final printer = DocumentPrint(
      print: (_, _, _) async {
        calls++;
        return true;
      },
    );
    await expectLater(
      printer.print(
        repository: repo,
        document: doc,
        pageWidth: 842,
        pageHeight: 595,
        uniformPages: true,
        encrypted: false,
        allowsPrinting: true,
      ),
      throwsA(
        isA<DocumentPrintException>().having(
          (e) => e.messageKey,
          'reason',
          'printTooLarge',
        ),
      ),
    );
    expect(calls, 0);
  });

  test('reader closed while preparing bytes prevents print dialog', () async {
    var calls = 0;
    final printer = DocumentPrint(
      print: (_, _, _) async {
        calls++;
        return true;
      },
    );
    await printer.print(
      repository: repo,
      document: doc,
      pageWidth: 842,
      pageHeight: 595,
      uniformPages: true,
      encrypted: false,
      allowsPrinting: true,
      isActive: () => false,
    );
    expect(calls, 0);
  });

  test('repeated calls coalesce and cancellation permits retry', () async {
    var calls = 0;
    final pending = Completer<bool>();
    final printer = DocumentPrint(
      print: (_, _, _) {
        calls++;
        return pending.future;
      },
    );
    final first = printer.print(
      repository: repo,
      document: doc,
      pageWidth: 842,
      pageHeight: 595,
      uniformPages: true,
      encrypted: false,
      allowsPrinting: true,
    );
    await printer.print(
      repository: repo,
      document: doc,
      pageWidth: 842,
      pageHeight: 595,
      uniformPages: true,
      encrypted: false,
      allowsPrinting: true,
    );
    pending.complete(false);
    await first;
    expect(calls, 1);
    await printer.print(
      repository: repo,
      document: doc,
      pageWidth: 842,
      pageHeight: 595,
      uniformPages: true,
      encrypted: false,
      allowsPrinting: true,
    );
    expect(calls, 2);
  });

  test('mixed or invalid page dimensions refuse native printing', () async {
    var calls = 0;
    final printer = DocumentPrint(
      print: (_, _, _) async {
        calls++;
        return true;
      },
    );
    for (final size in [
      (842.0, 595.0, false),
      (double.nan, 595.0, true),
      (0.0, 595.0, true),
    ]) {
      await expectLater(
        printer.print(
          repository: repo,
          document: doc,
          encrypted: false,
          allowsPrinting: true,
          pageWidth: size.$1,
          pageHeight: size.$2,
          uniformPages: size.$3,
        ),
        throwsA(isA<DocumentPrintException>()),
      );
    }
    expect(calls, 0);
  });

  test('native failure releases guard for retry', () async {
    var calls = 0;
    final printer = DocumentPrint(
      print: (_, _, _) async {
        calls++;
        throw StateError('test');
      },
    );
    for (var i = 0; i < 2; i++) {
      await expectLater(
        printer.print(
          repository: repo,
          document: doc,
          pageWidth: 842,
          pageHeight: 595,
          uniformPages: true,
          encrypted: false,
          allowsPrinting: true,
        ),
        throwsStateError,
      );
    }
    expect(calls, 2);
  });
}
