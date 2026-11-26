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

  testWidgets('phone screen shows Allow access without scrolling', (
    tester,
  ) async {
    // A common phone size: 393 × 780 logical pixels after system bars.
    tester.view.physicalSize = const Size(393, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final device = FakeDevicePdfs([phone.path], access: DeviceAccess.denied);
    await tester.pumpWidget(app(device));
    await settle(tester);
    await tester.tap(find.text(PaperStrings('en')['viewDevice']));
    await settle(tester);
    final allow = tester.getRect(find.byKey(const ValueKey('device-allow')));
    expect(allow.bottom, lessThanOrEqualTo(780));
    expect(tester.takeException(), isNull);
  });

  testWidgets('device folders filter the list and sort says date modified', (
    tester,
  ) async {
    final s = PaperStrings('en');
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final path in ['Download/a.pdf', 'Download/b.pdf', 'WhatsApp/c.pdf']) {
      File(p.join(phone.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync('%PDF-1.4 test');
    }
    await tester.pumpWidget(app(FakeDevicePdfs([phone.path])));
    await settle(tester);
    await tester.tap(find.text(s['viewDevice']));
    await settle(tester);
    expect(find.text(s['deviceSortModified']), findsOneWidget);
    expect(find.text(s['librarySortRecent']), findsNothing);
    expect(find.text('c.pdf'), findsOneWidget);
    await tester.tap(find.text('Download (2)'));
    await settle(tester);
    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('c.pdf'), findsNothing);
    await tester.tap(find.text(s['deviceAllFolders']));
    await settle(tester);
    expect(find.text('c.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favourites can be marked and filtered, with page progress', (
    tester,
  ) async {
    final s = PaperStrings('en');
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late PaperDocument first;
    await tester.runAsync(() async {
      first = await repository.importPdf(
        name: 'First.pdf',
        bytes: Stream.value('%PDF-1.4 one'.codeUnits),
      );
      await repository.importPdf(
        name: 'Second.pdf',
        bytes: Stream.value('%PDF-1.4 two'.codeUnits),
      );
      await repository.updateDocument(
        first.id,
        (d) => d.copyWith(
          lastPage: 3,
          pageCount: 5,
          lastOpenedAt: DateTime.utc(2026),
        ),
      );
    });
    await tester.pumpWidget(app(FakeDevicePdfs([phone.path])));
    await settle(tester);
    expect(find.textContaining('Page 3 of 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('favorites-only')), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.textContaining('First.pdf'),
          matching: find.byType(ListTile),
        ),
        matching: find.byTooltip(s['tools']),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(s['editPages']), findsOneWidget);
    await tester.tap(find.text(s['favorite']));
    // Saving runs real file I/O; pump until the library shows the result.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      if (find.byKey(const ValueKey('favorites-only')).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.tap(find.byKey(const ValueKey('favorites-only')));
    await settle(tester);
    expect(find.textContaining('First.pdf'), findsOneWidget);
    expect(find.textContaining('Second.pdf'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
