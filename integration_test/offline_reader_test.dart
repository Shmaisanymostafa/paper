import 'dart:io';

import 'package:cave_paper/services/document_share.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/data/offline_policy.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'bundled sample opens, extracts text and renders with HTTP forbidden',
    (tester) => HttpOverrides.runWithHttpOverrides(() async {
      final directory = await Directory.systemTemp.createTemp('paper-native-');
      try {
        await pdfrxFlutterInitialize();
        final asset = await rootBundle.load('assets/sample.pdf');
        final source = asset.buffer.asUint8List(
          asset.offsetInBytes,
          asset.lengthInBytes,
        );
        final repo = LibraryRepository(directory);
        final imported = await repo.importPdf(
          name: 'sample.pdf',
          bytes: Stream.value(source),
        );
        final doc = await PdfDocument.openFile(
          repo.documentFile(imported.id).path,
        );
        try {
          expect(doc.pages.length, 3);
          expect(
            (await doc.pages.first.loadText())?.fullText,
            contains('Cave Paper'),
          );
          final image = await doc.pages.first.render(width: 400, height: 566);
          expect(image, isNotNull);
          image?.dispose();
          await repo.verifyDocument(imported);
          var handedOff = false;
          await DocumentShare(
            share: (params) async {
              expect(await params.files!.first.readAsBytes(), source);
              expect(params.files!.first.path.endsWith('/sample.pdf'), isTrue);
              handedOff = true;
              return const ShareResult('', ShareResultStatus.dismissed);
            },
          ).share(
            repository: repo,
            document: imported,
            origin: const Rect.fromLTWH(0, 0, 100, 100),
            includeAnnotations: true,
          );
          expect(handedOff, isTrue);
        } finally {
          await doc.dispose();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    }, OfflineHttpOverrides()),
  );
}
