// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:cave_paper/data/library_repository.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/services/device_pdfs.dart';
import 'package:cave_paper/ui/library_screen.dart';
import 'package:cave_paper/ui/strings.dart';
import 'package:cave_paper/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Scans synchronously in the test isolate; native access is scripted.
class FakeDevicePdfs extends DevicePdfs {
  FakeDevicePdfs(this.rootsList, {this.access = DeviceAccess.granted})
    : super(platform: 'android');
  final List<String> rootsList;
  DeviceAccess access;
  DeviceAccess afterRequest = DeviceAccess.granted;
  int requests = 0;
  @override
  Future<DeviceAccess> status() async => access;
  @override
  Future<DeviceAccess> request() async {
    requests++;
    return access = afterRequest;
  }

  @override
  Future<List<String>> roots() async => rootsList;
  @override
  Future<DeviceScanResult> scan(List<String> roots) async => scanForPdfs(roots);
}

void main() {
  late Directory root, phone;
  late LibraryRepository repository;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('paper-device-ui-');
    phone = Directory(p.join(root.path, 'phone'))..createSync();
    repository = LibraryRepository(Directory(p.join(root.path, 'library')));
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  Widget app(FakeDevicePdfs device, {String language = 'en'}) => MaterialApp(
    theme: PaperTheme.build(Appearance.light, language: language),
    home: LibraryScreen(
      repository: repository,
      settings: PaperSettings(language: language),
      onSettingsChanged: (_) async {},
      strings: PaperStrings(language),
      devicePdfs: device,
    ),
  );

  for (final language in ['en', 'ar']) {
    testWidgets('$language: device view asks first, then lists PDFs', (
      tester,
    ) async {
      final s = PaperStrings(language);
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      File(p.join(phone.path, 'Download', 'Invoice.pdf'))
        ..createSync(recursive: true)
        ..writeAsStringSync('%PDF-1.4 test');
      final device = FakeDevicePdfs([phone.path], access: DeviceAccess.denied);
      await tester.pumpWidget(app(device, language: language));
      await settle(tester);
      expect(find.text(s['viewDevice']), findsOneWidget);
      // Nothing is listed or requested before the person chooses the tab.
      expect(device.requests, 0);
      await tester.tap(find.text(s['viewDevice']));
      await settle(tester);
      expect(find.text(s['deviceAccessTitle']), findsOneWidget);
      expect(find.text('Invoice.pdf'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('device-allow')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('device-allow')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('device-allow')));
      await settle(tester);
      expect(device.requests, 1);
      expect(find.text('Invoice.pdf'), findsOneWidget);
      expect(
        find.text(s['deviceCount'].replaceAll('{count}', '1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending access is checked again when the app resumes', (
    tester,
  ) async {
    File(p.join(phone.path, 'a.pdf')).writeAsStringSync('%PDF-1.4 test');
    final device = FakeDevicePdfs([phone.path], access: DeviceAccess.denied)
      ..afterRequest = DeviceAccess.pending;
    await tester.pumpWidget(app(device));
    await settle(tester);
    await tester.tap(find.text(PaperStrings('en')['viewDevice']));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('device-allow')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('device-allow')));
    await settle(tester);
    expect(find.text(PaperStrings('en')['devicePending']), findsOneWidget);
    device.access = DeviceAccess.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(find.text('a.pdf'), findsOneWidget);
  });

  testWidgets('files already imported are marked In library', (tester) async {
    final original = File(p.join(phone.path, 'Lease.pdf'))
      ..writeAsStringSync('%PDF-1.4 lease agreement');
    File(p.join(phone.path, 'Other.pdf')).writeAsStringSync('%PDF-1.4 other');
    await tester.runAsync(
      () => repository.importPdf(name: 'Lease.pdf', bytes: original.openRead()),
    );
    await tester.pumpWidget(app(FakeDevicePdfs([phone.path])));
    await settle(tester);
    await tester.tap(find.text(PaperStrings('en')['viewDevice']));
    await settle(tester);
    expect(find.text('Lease.pdf'), findsOneWidget);
    expect(find.text('Other.pdf'), findsOneWidget);
    expect(find.text(PaperStrings('en')['deviceInLibrary']), findsOneWidget);
  });

  testWidgets('device search filters by file name', (tester) async {
    for (final name in ['Tax 2025.pdf', 'Recipe.pdf']) {
      File(p.join(phone.path, name)).writeAsStringSync('%PDF-1.4 $name');
    }
    await tester.pumpWidget(app(FakeDevicePdfs([phone.path])));
    await settle(tester);
    await tester.tap(find.text(PaperStrings('en')['viewDevice']));
    await settle(tester);
    expect(find.text('Recipe.pdf'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'tax');
    await tester.pump();
    expect(find.text('Tax 2025.pdf'), findsOneWidget);
    expect(find.text('Recipe.pdf'), findsNothing);
  });

  testWidgets('no device tab when the platform cannot list files', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          repository: repository,
          settings: const PaperSettings(),
          onSettingsChanged: (_) async {},
          strings: PaperStrings('en'),
          devicePdfs: DevicePdfs(platform: 'ios'),
        ),
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('library-view')), findsNothing);
  });

  test('Black appearance round-trips and themes use 10px buttons', () {
    final settings = PaperSettings.fromJson(
      const PaperSettings(appearance: Appearance.black).toJson(),
    );
    expect(settings.appearance, Appearance.black);
    for (final palette in [
      Appearance.light,
      Appearance.dark,
      Appearance.black,
    ]) {
      final theme = PaperTheme.build(palette, language: 'en');
      final shape = theme.filledButtonTheme.style!.shape!.resolve({});
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        const BorderRadius.all(Radius.circular(10)),
      );
    }
    expect(
      PaperTheme.build(
        Appearance.black,
        language: 'en',
      ).scaffoldBackgroundColor,
      PaperTheme.charcoal,
    );
  });
}
