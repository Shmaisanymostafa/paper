// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/library_repository.dart';
import 'data/offline_policy.dart';
import 'domain/library.dart';
import 'services/device_pdfs.dart';
import 'services/document_thumbnails.dart';
import 'ui/library_screen.dart';
import 'ui/strings.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = OfflineHttpOverrides();
  LicenseRegistry.addLicense(() async* {
    for (final name in [
      'plex-sans-LICENSE.txt',
      'plex-sans-arabic-LICENSE.txt',
      'pdfrx-LICENSE.txt',
      'resolved-packages.txt',
      'pdfium-macos-arm64-LICENSE.txt',
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/notices/$name'));
    }
  });
  runApp(const PaperBootstrap());
}

class PaperBootstrap extends StatefulWidget {
  const PaperBootstrap({super.key});
  @override
  State<PaperBootstrap> createState() => _PaperBootstrapState();
}

class _PaperBootstrapState extends State<PaperBootstrap> {
  late Future<LibraryRepository> _repository;
  @override
  void initState() {
    super.initState();
    _repository = _open();
  }

  Future<LibraryRepository> _open() async {
    final support = await getApplicationSupportDirectory();
    return LibraryRepository(Directory(p.join(support.path, 'paper-library')));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _repository,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final repository = snapshot.data!;
        return PaperApp(
          repository: repository,
          devicePdfs: DevicePdfs(),
          thumbnails: DocumentThumbnails(repository),
        );
      }
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Local storage unavailable / التخزين المحلي غير متاح',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {
                          _repository = _open();
                        }),
                        child: const Text('Retry / إعادة المحاولة'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}

class PaperApp extends StatefulWidget {
  const PaperApp({
    required this.repository,
    this.devicePdfs,
    this.thumbnails,
    super.key,
  });
  final LibraryRepository repository;

  /// Optional so tests stay free of native channels and PDFium rendering.
  final DevicePdfs? devicePdfs;
  final DocumentThumbnails? thumbnails;
  @override
  State<PaperApp> createState() => _PaperAppState();
}

class _PaperAppState extends State<PaperApp> {
  PaperSettings _settings = const PaperSettings();
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final state = await widget.repository.load();
      if (mounted) {
        setState(() {
          _settings = state.settings;
          _ready = true;
        });
      }
    } catch (_) {
      // LibraryScreen presents the recoverable storage error; never reset it.
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _changeSettings(PaperSettings settings) async {
    final state = await widget.repository.setDisplaySettings(settings);
    if (mounted) setState(() => _settings = state.settings);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cave Paper',
    debugShowCheckedModeBanner: false,
    locale: Locale(_settings.language),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: PaperTheme.build(Appearance.light, language: _settings.language),
    // Black is a dark-mode theme; System follows the OS with standard Dark.
    darkTheme: PaperTheme.build(
      _settings.appearance == Appearance.black
          ? Appearance.black
          : Appearance.dark,
      language: _settings.language,
    ),
    themeMode: switch (_settings.appearance) {
      Appearance.system => ThemeMode.system,
      Appearance.light => ThemeMode.light,
      Appearance.dark || Appearance.black => ThemeMode.dark,
    },
    home: !_ready
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : LibraryScreen(
            repository: widget.repository,
            settings: _settings,
            onSettingsChanged: _changeSettings,
            strings: PaperStrings(_settings.language),
            devicePdfs: widget.devicePdfs,
            thumbnails: widget.thumbnails,
          ),
  );
}
