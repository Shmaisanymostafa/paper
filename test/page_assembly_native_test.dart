import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/data/offline_policy.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/domain/page_edit.dart';
import 'package:cave_paper/services/page_assembly.dart';

void main() {
  test(
    'real PDF edit merges, reorders, rotates and deletes into a new document',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final dir = await Directory.systemTemp.createTemp('paper-assembly-');
      try {
        await pdfrxInitialize(tmpPath: dir.path);
        final bytes = await File('assets/sample.pdf').readAsBytes();
        final repo = LibraryRepository(
          await Directory('${dir.path}/library').create(),
        );
        final original = await repo.importPdf(
          name: 'sample.pdf',
          bytes: Stream.value(bytes),
        );
        final source = await PdfDocument.openData(bytes);
        final count = source.pages.length;
        final texts = <String>[];
        final widths = <double>[];
        try {
          for (final page in source.pages) {
            texts.add((await page.loadText())!.fullText);
            widths.add(page.width);
          }
        } finally {
          await source.dispose();
        }
        expect(count, greaterThanOrEqualTo(3));

        // Merge the document with itself, drop page 2, move the last page to
        // the front and turn it a quarter clockwise.
        var plan = PageEditPlan.of(original.id, count).append(original.id, 1);
        plan = plan.remove({plan.pages[1].key});
        plan = plan.move(plan.length - 1, 0);
        plan = plan.rotate({plan.pages.first.key}, 1);
        final expected = [for (final p in plan.pages) p.page];

        final saved = await PageAssembly().saveToLibrary(
          repository: repo,
          plan: plan,
          title: 'sample (edited).pdf',
        );
        expect(saved.id, isNot(original.id));
        final state = await repo.load();
        expect(state.documents.length, 2);
        expect(state.find(saved.id)!.pageCount, plan.length);
        expect(state.find(saved.id)!.title, 'sample (edited).pdf');

        final edited = await PdfDocument.openFile(
          repo.documentFile(saved.id).path,
        );
        try {
          expect(edited.pages.length, plan.length);
          // Rotation can change text extraction order, so compare lines.
          List<String> lines(String text) =>
              text.replaceAll(' 1 / 3', '\r\n1 / 3').split('\r\n')..sort();
          for (var i = 0; i < plan.length; i++) {
            final text = (await edited.pages[i].loadText())!.fullText;
            final want = texts[expected[i] - 1];
            if (plan.pages[i].turns == 0) {
              expect(text, want);
            } else {
              expect(lines(text), lines(want));
            }
          }
          // A quarter turn swaps the displayed width and height.
          expect(edited.pages.first.height, closeTo(widths[0], 0.5));
        } finally {
          await edited.dispose();
        }
        // The original is byte-for-byte unchanged.
        expect(await repo.documentFile(original.id).readAsBytes(), bytes);
        await repo.verifyDocument(original);

        for (final name in ['assembly-restricted', 'password-protected']) {
          final protectedBytes = await File('test/fixtures/$name.pdf')
              .readAsBytes();
          final protected = await repo.importPdf(
            name: '$name.pdf',
            bytes: Stream.value(protectedBytes),
          );
          final before = (await repo.load()).toJson();
          await expectLater(
            PageAssembly().saveToLibrary(
              repository: repo,
              plan: PageEditPlan.of(original.id, 1).append(protected.id, 1),
              title: 'x.pdf',
            ),
            throwsA(isA<LibraryFormatException>()),
          );
          expect((await repo.load()).toJson(), before);
        }
      } finally {
        await dir.delete(recursive: true);
      }
    }, OfflineHttpOverrides()),
    skip: Platform.environment['PDFIUM_PATH'] == null
        ? 'Set PDFIUM_PATH to the audited local native library for this headless integration.'
        : false,
  );
}
