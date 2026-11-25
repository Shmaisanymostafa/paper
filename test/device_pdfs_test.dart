// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:cave_paper/services/default_pdf_app.dart';
import 'package:cave_paper/services/device_pdfs.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('paper-device-');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  File write(String relative, {int bytes = 32, DateTime? modified}) {
    final file = File(p.join(root.path, relative))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(bytes, 37));
    if (modified != null) file.setLastModifiedSync(modified);
    return file;
  }

  test('finds PDFs in nested folders, newest first, without reading bytes', () {
    write('a.pdf', modified: DateTime(2026, 1, 1));
    write('Documents/Work/Report.PDF', modified: DateTime(2026, 3, 1));
    write('Download/b.pdf', modified: DateTime(2026, 2, 1));
    write('Download/notes.txt');
    write('Download/tiny.pdf', bytes: 4);
    final result = scanForPdfs([root.path]);
    expect(result.incomplete, isFalse);
    expect(result.files.map((f) => f.name), ['Report.PDF', 'b.pdf', 'a.pdf']);
    expect(result.files.first.bytes, 32);
  });

  test('skips hidden folders, private Android app data and links', () {
    write('.cache/hidden.pdf');
    write('Android/data/com.other/private.pdf');
    write('Android/obb/com.other/game.pdf');
    write('Android/media/com.whatsapp/WhatsApp Documents/shared.pdf');
    write('node_modules/pkg/readme.pdf');
    final outside = Directory.systemTemp.createTempSync('paper-outside-');
    addTearDown(() => outside.deleteSync(recursive: true));
    File(p.join(outside.path, 'outside.pdf'))
        .writeAsBytesSync(List.filled(32, 1));
    Link(p.join(root.path, 'linked')).createSync(outside.path);
    Link(p.join(root.path, 'linked.pdf'))
        .createSync(p.join(outside.path, 'outside.pdf'));
    final names = scanForPdfs([root.path]).files.map((f) => f.name).toList();
    expect(names, ['shared.pdf']);
  });

  test('limits stop the walk and report an incomplete list', () {
    for (var i = 0; i < 10; i++) {
      write('f$i.pdf');
    }
    final capped = scanForPdfs([root.path], maxResults: 3);
    expect(capped.files, hasLength(3));
    expect(capped.incomplete, isTrue);
    expect(scanForPdfs([root.path], maxEntries: 4).incomplete, isTrue);
    write('one/two/three/deep.pdf');
    expect(
      scanForPdfs([root.path], maxDepth: 2).files.map((f) => f.name),
      isNot(contains('deep.pdf')),
    );
  });

  test('missing roots and duplicate roots are harmless', () {
    write('x.pdf');
    final result = scanForPdfs([
      p.join(root.path, 'missing'),
      root.path,
      root.path,
    ]);
    expect(result.files, hasLength(1));
  });

  test('listing filters by name and can sort by name', () {
    final files = [
      DevicePdf(path: '/a/zeta.pdf', bytes: 10, modified: DateTime(2026, 5)),
      DevicePdf(path: '/a/Alpha.pdf', bytes: 10, modified: DateTime(2026, 1)),
      DevicePdf(path: '/b/beta.pdf', bytes: 10, modified: DateTime(2026, 9)),
    ];
    expect(deviceListing(files, query: '').map((f) => f.name), [
      'beta.pdf',
      'zeta.pdf',
      'Alpha.pdf',
    ]);
    expect(deviceListing(files, query: '', byName: true).map((f) => f.name), [
      'Alpha.pdf',
      'beta.pdf',
      'zeta.pdf',
    ]);
    expect(deviceListing(files, query: ' ALP ').single.name, 'Alpha.pdf');
  });

  test('platform rules: where each OS looks', () async {
    final linux = DevicePdfs(
      platform: 'linux',
      environment: {'HOME': '/home/a'},
    );
    expect(await linux.roots(), [
      '/home/a/Desktop',
      '/home/a/Documents',
      '/home/a/Downloads',
    ]);
    expect(await linux.status(), DeviceAccess.granted);
    expect(linux.automatic && linux.folderPicker, isTrue);
    final windows = DevicePdfs(
      platform: 'windows',
      environment: {'USERPROFILE': r'C:\Users\a'},
    );
    expect((await windows.roots()).first, r'C:\Users\a\Desktop');
    final mac = DevicePdfs(platform: 'macos');
    expect(await mac.roots(), isEmpty);
    expect(mac.automatic, isFalse);
    expect(mac.folderPicker, isTrue);
    final ios = DevicePdfs(platform: 'ios');
    expect(ios.supported, isFalse);
    expect(await ios.status(), DeviceAccess.unavailable);
  });

  test('Android asks the native side and parses its answers', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    var status = 'denied';
    messenger.setMockMethodCallHandler(DevicePdfs.channel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'status' => status,
        'request' => 'pending',
        'roots' => ['/storage/emulated/0'],
        _ => null,
      };
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(DevicePdfs.channel, null),
    );
    final android = DevicePdfs(platform: 'android');
    expect(android.folderPicker, isFalse);
    expect(await android.status(), DeviceAccess.denied);
    expect(await android.request(), DeviceAccess.pending);
    status = 'granted';
    expect(await android.status(), DeviceAccess.granted);
    expect(await android.roots(), ['/storage/emulated/0']);
    status = 'surprise';
    expect(await android.status(), DeviceAccess.unavailable);
    expect(calls, ['status', 'request', 'status', 'roots', 'status']);
  });

  test('scan runs on a background isolate', () async {
    write('Documents/x.pdf');
    final result = await DevicePdfs(platform: 'linux').scan([root.path]);
    expect(result.files.single.name, 'x.pdf');
  });

  test('default app help never changes defaults itself', () async {
    final started = <List<String>>[];
    final windows = DefaultPdfApp(
      platform: 'windows',
      start: (exe, args) async => started.add([exe, ...args]),
    );
    expect(windows.stepsKey, 'defaultAppWindows');
    await windows.openSettings();
    expect(started, [
      ['explorer.exe', 'ms-settings:defaultapps'],
    ]);
    for (final platform in ['android', 'ios', 'macos', 'linux']) {
      final app = DefaultPdfApp(
        platform: platform,
        start: (_, _) async => fail('must not start a process'),
      );
      expect(app.canOpenSettings, isFalse);
      expect(() => app.openSettings(), throwsUnsupportedError);
    }
    expect(DefaultPdfApp(platform: 'macos').stepsKey, 'defaultAppMacos');
  });

  test('unknown method channel errors surface to the caller', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      DevicePdfs.channel,
      (call) async => throw PlatformException(code: 'x'),
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(DevicePdfs.channel, null),
    );
    expect(
      DevicePdfs(platform: 'android').status(),
      throwsA(isA<PlatformException>()),
    );
  });
}
