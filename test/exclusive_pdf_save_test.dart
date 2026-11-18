import 'dart:io';
import 'dart:typed_data';

import 'package:cave_paper/services/exclusive_pdf_save.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final linkAttack in [false, true]) {
    test(
      'no-replace publication rejects ${linkAttack ? 'symlink' : 'file'} race',
      () async {
        final dir = await Directory.systemTemp.createTemp('paper-save-race-');
        try {
          final library = await Directory('${dir.path}/library').create();
          final original = File('${dir.path}/original.pdf');
          await original.writeAsString('untouched original');
          final target = '${dir.path}/copy.pdf';
          await expectLater(
            ExclusivePdfSave.save(
              path: target,
              bytes: Uint8List.fromList([1, 2, 3]),
              libraryRoot: library,
              beforePublish: () async {
                if (linkAttack) {
                  await Link(target).create(original.path);
                } else {
                  await File(target).writeAsString('concurrent existing file');
                }
              },
            ),
            throwsA(isA<FileSystemException>()),
          );
          expect(await original.readAsString(), 'untouched original');
          expect(
            await File(target).readAsString(),
            linkAttack ? 'untouched original' : 'concurrent existing file',
          );
          expect(
            await dir
                .list()
                .where((f) => f.path.contains('.paper-copy-'))
                .toList(),
            isEmpty,
          );
        } finally {
          await dir.delete(recursive: true);
        }
      },
      skip: !ExclusivePdfSave.supported,
    );
  }
  test('failed staging never publishes incomplete target', () async {
    final dir = await Directory.systemTemp.createTemp('paper-save-failure-');
    try {
      final library = await Directory('${dir.path}/library').create();
      final target = '${dir.path}/copy.pdf';
      await expectLater(
        ExclusivePdfSave.save(
          path: target,
          bytes: Uint8List.fromList([1, 2, 3]),
          libraryRoot: library,
          beforePublish: () async {
            throw const FileSystemException(
              'injected failure before publication',
            );
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(target).exists(), isFalse);
      expect(
        await dir.list().where((f) => f.path.contains('.paper-copy-')).toList(),
        isEmpty,
      );
    } finally {
      await dir.delete(recursive: true);
    }
  }, skip: !ExclusivePdfSave.supported);
}
