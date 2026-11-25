// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:typed_data';

import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/services/exclusive_file_save.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late Directory library;
  final bytes = Uint8List.fromList('{"notes":[]}'.codeUnits);

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('paper-json-save-');
    library = await Directory('${temporary.path}/library').create();
  });
  tearDown(() => temporary.delete(recursive: true));

  Future<void> save(String path, {Future<void> Function()? beforePublish}) =>
      ExclusiveFileSave.save(
        path: path,
        bytes: bytes,
        libraryRoot: library,
        extension: '.json',
        beforePublish: beforePublish,
      );

  test('annotation publication creates a new JSON outside library', () async {
    final target = File('${temporary.path}/notes.json');
    await save(target.path);
    expect(await target.readAsBytes(), bytes);
    await expectLater(save(target.path), throwsA(isA<FileSystemException>()));
    expect(await target.readAsBytes(), bytes);
    await expectLater(
      save('${temporary.path}/original.pdf'),
      throwsA(isA<LibraryFormatException>()),
    );
    await expectLater(
      save('${library.path}/notes.json'),
      throwsA(isA<LibraryFormatException>()),
    );
    final alias = Link('${temporary.path}/library-alias');
    await alias.create(library.path);
    await expectLater(
      save('${alias.path}/notes.json'),
      throwsA(isA<LibraryFormatException>()),
    );
  }, skip: !ExclusiveFileSave.supported);

  for (final concurrent in [false, true]) {
    for (final kind in ['file', 'symlink', 'hardlink']) {
      test(
        'JSON refuses ${concurrent ? 'concurrent' : 'existing'} $kind without changing PDF',
        () async {
          final original = File('${temporary.path}/original.pdf');
          const originalText =
              '%PDF-1.7\nOriginal must remain unchanged\n%%EOF';
          await original.writeAsString(originalText);
          final target = File('${temporary.path}/notes.json');
          Future<void> createTarget() async {
            switch (kind) {
              case 'file':
                await target.writeAsString('existing annotations');
              case 'symlink':
                await Link(target.path).create(original.path);
              case 'hardlink':
                final result = await Process.run('ln', [
                  original.path,
                  target.path,
                ]);
                expect(result.exitCode, 0, reason: '${result.stderr}');
            }
          }

          if (!concurrent) await createTarget();
          await expectLater(
            save(target.path, beforePublish: concurrent ? createTarget : null),
            throwsA(isA<FileSystemException>()),
          );
          expect(await original.readAsString(), originalText);
          expect(
            await target.readAsString(),
            kind == 'file' ? 'existing annotations' : originalText,
          );
          expect(
            await temporary
                .list()
                .where((f) => f.path.contains('.paper-copy-'))
                .toList(),
            isEmpty,
          );
        },
        skip: !ExclusiveFileSave.supported,
      );
    }
  }
}
