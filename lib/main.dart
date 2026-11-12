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
import 'ui/library_screen.dart';
import 'ui/strings.dart';

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
      if (snapshot.hasData) return PaperApp(repository: snapshot.data!);
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
  const PaperApp({required this.repository, super.key});
  final LibraryRepository repository;
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
    await widget.repository.setSettings(settings);
    if (mounted) setState(() => _settings = settings);
  }

  ThemeData _theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF147F79),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: _settings.language == 'ar'
          ? 'IBMPlexSansArabic'
          : 'IBMPlexSans',
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF5F7F6)
          : const Color(0xFF10232C),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      visualDensity: VisualDensity.standard,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cave Paper',
    debugShowCheckedModeBanner: false,
    locale: Locale(_settings.language),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: switch (_settings.appearance) {
      Appearance.system => ThemeMode.system,
      Appearance.light => ThemeMode.light,
      Appearance.dark => ThemeMode.dark,
    },
    home: !_ready
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : LibraryScreen(
            repository: widget.repository,
            settings: _settings,
            onSettingsChanged: _changeSettings,
            strings: PaperStrings(_settings.language),
          ),
  );
}
