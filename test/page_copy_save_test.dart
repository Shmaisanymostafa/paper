import 'dart:io';
import 'dart:typed_data';

import 'package:cave_paper/services/page_copy.dart';
import 'package:cave_paper/services/exclusive_pdf_save.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'save creates new external file and refuses original, symlink and library',
    () async {
      final dir = await Directory.systemTemp.createTemp('paper-safe-save-');
      try {
        final root = await Directory('${dir.path}/library').create();
        final bytes = Uint8List.fromList([37, 80, 68, 70, 45, 49]);
        Future<void> save(String path) =>
            PageCopy.saveNewFile(path: path, bytes: bytes, libraryRoot: root);
        final output = '${dir.path}/copy.pdf';
        await save(output);
        expect(await File(output).readAsBytes(), bytes);
        await expectLater(save(output), throwsException);
        expect(await File(output).readAsBytes(), bytes);
        await expectLater(save('${root.path}/managed.pdf'), throwsException);
        expect(await File('${root.path}/managed.pdf').exists(), isFalse);
        await expectLater(save('${dir.path}/copy.txt'), throwsException);
        await expectLater(save('relative.pdf'), throwsException);
        await expectLater(save('${dir.path}/nul\u0000.pdf'), throwsException);
        expect(await File('${dir.path}/nul').exists(), isFalse);
        if (!Platform.isWindows) {
          final link = Link('${dir.path}/alias.pdf');
          await link.create(output);
          await expectLater(save(link.path), throwsException);
          final folderLink = Link('${dir.path}/linked-library');
          await folderLink.create(root.path);
          await expectLater(
            save('${folderLink.path}/inside.pdf'),
            throwsException,
          );
        }
      } finally {
        await dir.delete(recursive: true);
      }
    },
    skip: !ExclusivePdfSave.supported,
  );
}
