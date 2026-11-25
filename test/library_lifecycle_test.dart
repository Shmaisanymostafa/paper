// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';

import 'package:cave_paper/data/external_documents.dart';
import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/ui/library_screen.dart';
import 'package:cave_paper/ui/strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('late native ready paths are released after screen disposal', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('paper-late-external-'),
    ))!;
    final repository = LibraryRepository(root);
    await tester.runAsync(repository.load);
    final ready = Completer<List<String>>();
    final releases = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(ExternalDocuments.channel, (call) async {
      if (call.method == 'ready') return ready.future;
      if (call.method == 'release') releases.add(call.arguments as String);
      return null;
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(ExternalDocuments.channel, null);
      await tester.runAsync(() => root.delete(recursive: true));
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          repository: repository,
          settings: const PaperSettings(),
          onSettingsChanged: (_) async {},
          strings: PaperStrings('en'),
        ),
      ),
    );
    // Let the real filesystem load finish before disposing its widget. A new
    // runAsync repository read must not wait on work queued in fake async.
    for (
      var i = 0;
      i < 50 && find.text(PaperStrings('en')['open']).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.text(PaperStrings('en')['open']), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    ready.complete(['/tmp/late-native-document.pdf']);
    await tester.pumpAndSettle();
    expect(releases, ['/tmp/late-native-document.pdf']);
    expect(
      await tester.runAsync(() => Directory('${root.path}/documents').exists()),
      false,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('native ready failure leaves the picker UI available', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('paper-external-failure-'),
    ))!;
    final repository = LibraryRepository(root);
    await tester.runAsync(repository.load);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(ExternalDocuments.channel, (call) async {
      throw PlatformException(code: 'native-ready-failed');
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      messenger.setMockMethodCallHandler(ExternalDocuments.channel, null);
      await tester.runAsync(() => root.delete(recursive: true));
    });
    final strings = PaperStrings('en');
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          repository: repository,
          settings: const PaperSettings(),
          onSettingsChanged: (_) async {},
          strings: strings,
        ),
      ),
    );
    for (
      var i = 0;
      i < 50 && find.text(strings['open']).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text(strings['open']), findsOneWidget);
    expect(find.text(strings['importError']), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
