import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cave_paper/services/folder_discovery.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('paper-folder-test-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('shallow candidate discovery never imports or modifies files', () async {
    final pdf = File('${root.path}/sample.PDF');
    await pdf.writeAsString('synthetic metadata fixture');
    await File('${root.path}/empty.pdf').create();
    await File('${root.path}/other.txt').writeAsString('leave me');
    final nested = await Directory('${root.path}/nested').create();
    await File('${nested.path}/private.pdf').writeAsString('not scanned');
    final result = await FolderDiscovery().scan(root);
    expect(result.incomplete, false);
    expect(result.candidates.map((c) => c.path), [pdf.path]);
    expect(result.candidates.single.bytes, 26);
    expect(await pdf.readAsString(), 'synthetic metadata fixture');
    expect(() => result.candidates.clear(), throwsUnsupportedError);
  });

  test(
    'entry cap and cancellation report incomplete without scanning device',
    () async {
      for (var i = 0; i < 4; i++) {
        await File('${root.path}/$i.pdf').writeAsString('x');
      }
      final capped = await FolderDiscovery().scan(root, maxEntries: 2);
      expect(capped.incomplete, true);
      expect(capped.candidates.length, 2);
      final cancelled = await FolderDiscovery().scan(
        root,
        cancelled: () => true,
      );
      expect(cancelled.incomplete, true);
      expect(cancelled.candidates, isEmpty);
      await expectLater(
        FolderDiscovery().scan(root, maxEntries: 0),
        throwsArgumentError,
      );
    },
  );

  test(
    'cancellation during final metadata excludes the late candidate',
    () async {
      await File('${root.path}/last.pdf').writeAsString('x');
      var checks = 0;
      final result = await FolderDiscovery().scan(
        root,
        cancelled: () => ++checks >= 5,
      );
      expect(checks, greaterThanOrEqualTo(5));
      expect(result.incomplete, true);
      expect(result.candidates, isEmpty);
    },
  );

  test('missing roots rejected and linked files/roots not traversed', () async {
    await expectLater(
      FolderDiscovery().scan(Directory('${root.path}/missing')),
      throwsA(isA<FileSystemException>()),
    );
    if (Platform.isWindows) return; // Symlink creation may need privilege.
    final outside = await Directory.systemTemp.createTemp(
      'paper-outside-test-',
    );
    try {
      final original = await File('${outside.path}/private.pdf')
          .writeAsString('original');
      await Link('${root.path}/alias.pdf').create(original.path);
      final alias = await Link('${root.path}/alias-dir').create(outside.path);
      expect((await FolderDiscovery().scan(root)).candidates, isEmpty);
      await expectLater(
        FolderDiscovery().scan(Directory(alias.path)),
        throwsA(isA<FileSystemException>()),
      );
      expect(await original.readAsString(), 'original');
    } finally {
      await outside.delete(recursive: true);
    }
  });
}
