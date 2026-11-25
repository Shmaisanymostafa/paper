// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../data/external_documents.dart';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/library_repository.dart';
import '../domain/library.dart';
import '../services/default_pdf_app.dart';
import '../services/device_pdfs.dart';
import '../services/document_thumbnails.dart';
import 'reader_screen.dart';
import '../domain/library_listing.dart';
import 'strings.dart';
import 'file_access_dialog.dart';
import 'theme.dart';

enum LibraryView { library, device }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.repository,
    required this.settings,
    required this.onSettingsChanged,
    required this.strings,
    this.devicePdfs,
    this.thumbnails,
    this.defaultPdfApp,
    super.key,
  });
  final LibraryRepository repository;
  final PaperSettings settings;
  final Future<void> Function(PaperSettings) onSettingsChanged;
  final PaperStrings strings;

  /// Enables "On this device" when supported on this platform.
  final DevicePdfs? devicePdfs;

  /// First-page previews; without it the library shows the PDF icon.
  final DocumentThumbnails? thumbnails;
  final DefaultPdfApp? defaultPdfApp;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with WidgetsBindingObserver {
  LibraryView _view = LibraryView.library;
  DeviceAccess? _deviceAccess;
  DeviceScanResult? _deviceResult;
  List<String> _deviceRoots = const [];
  final List<String> _addedFolders = [];
  bool _scanning = false;
  late final DefaultPdfApp _defaultApp =
      widget.defaultPdfApp ?? DefaultPdfApp();
  bool get _deviceSupported => widget.devicePdfs?.supported ?? false;
  final _external = ExternalDocuments();
  final List<String> _pendingExternal = [];
  bool _openingExternal = false;
  PaperLibrary? _library;
  bool _busy = false, _savingRail = false, _settingsOpen = false;
  bool _explainedImport = false;
  String? _error;
  String _query = '';
  final _searchController = TextEditingController();
  LibrarySort _sort = LibrarySort.recent;
  PaperStrings get s => widget.strings;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    unawaited(_startExternal());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android grants All files access on its own settings screen; check again
    // when the person returns.
    if (state == AppLifecycleState.resumed &&
        _view == LibraryView.device &&
        _deviceAccess != DeviceAccess.granted) {
      unawaited(_refreshDevice());
    }
  }

  Future<void> _showView(LibraryView view) async {
    if (view == _view) return;
    setState(() => _view = view);
    if (view == LibraryView.device && _deviceResult == null) {
      await _refreshDevice();
    }
  }

  Future<void> _refreshDevice() async {
    final device = widget.devicePdfs;
    if (device == null) return;
    DeviceAccess access;
    try {
      access = await device.status();
    } catch (_) {
      access = DeviceAccess.unavailable;
    }
    if (!mounted) return;
    setState(() => _deviceAccess = access);
    if (access == DeviceAccess.granted) await _scanDevice();
  }

  Future<void> _allowDevice() async {
    final device = widget.devicePdfs;
    if (device == null) return;
    DeviceAccess access;
    try {
      access = await device.request();
    } catch (_) {
      access = DeviceAccess.unavailable;
    }
    if (!mounted) return;
    setState(() => _deviceAccess = access);
    if (access == DeviceAccess.granted) await _scanDevice();
  }

  Future<void> _scanDevice() async {
    final device = widget.devicePdfs;
    if (device == null || _scanning) return;
    setState(() => _scanning = true);
    try {
      final roots = <String>{
        ...await device.roots(),
        ..._addedFolders,
      }.toList();
      final result = roots.isEmpty
          ? const DeviceScanResult([], incomplete: false)
          : await device.scan(roots);
      if (mounted) {
        setState(() {
          _deviceRoots = roots;
          _deviceResult = result;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _deviceResult ??= const DeviceScanResult([], incomplete: true),
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s['deviceScanError'])));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _addFolder() async {
    final path = await fs.getDirectoryPath(
      confirmButtonText: s['deviceAddFolder'],
    );
    if (path == null || !mounted) return;
    if (!_addedFolders.contains(path)) _addedFolders.add(path);
    await _scanDevice();
  }

  Future<void> _openDevicePdf(DevicePdf pdf) => _run(() async {
    final file = File(pdf.path);
    if (await file.length() > maxImportBytes) {
      throw const LibraryFormatException('PDF exceeds 200 MiB.');
    }
    final doc = await widget.repository.importPdf(
      name: pdf.name,
      bytes: file.openRead(),
    );
    await _load();
    if (mounted) await _read(doc);
  }, error: 'importError');

  Future<void> _showDefaultApp() async {
    final app = _defaultApp;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s['defaultApp']),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(s[app.stepsKey]),
                const SizedBox(height: 12),
                Text(
                  s['defaultAppNever'],
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(s['close']),
          ),
          if (app.canOpenSettings)
            FilledButton(
              onPressed: () async {
                try {
                  await app.openSettings();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s['defaultAppSettingsError'])),
                    );
                  }
                }
              },
              child: Text(s['defaultAppOpenSettings']),
            ),
        ],
      ),
    );
  }

  Future<void> _startExternal() async {
    try {
      await _external.start((path) {
        // The native ready response can arrive after this screen is gone.
        // Release its security-scoped access rather than orphaning the grant.
        if (!mounted) {
          unawaited(_releaseExternal(path));
          return;
        }
        _pendingExternal.add(path);
        unawaited(_drainExternal());
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s['importError'])));
      }
    }
  }

  Future<void> _releaseExternal(String path) async {
    try {
      await _external.release(path);
    } catch (_) {
      // A native release failure must not become an uncaught async exception
      // or prevent the remaining queued access grants from being released.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s['importError'])));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _external.dispose();
    for (final path in _pendingExternal) {
      unawaited(_releaseExternal(path));
    }
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Future<void> _drainExternal() async {
    if (_openingExternal) return;
    _openingExternal = true;
    try {
      while (mounted && _pendingExternal.isNotEmpty) {
        final path = _pendingExternal.removeAt(0);
        var released = false;
        try {
          final file = File(path);
          if (!p.isAbsolute(path) ||
              !path.toLowerCase().endsWith('.pdf') ||
              await file.length() > 200 * 1024 * 1024) {
            throw const FormatException('Unsupported incoming PDF');
          }
          final doc = await widget.repository.importPdf(
            name: p.basename(path),
            bytes: file.openRead(),
          );
          await _releaseExternal(path);
          released = true;
          await _load();
          if (mounted) await _read(doc);
        } catch (_) {
          if (!released) await _releaseExternal(path);
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(s['importError'])));
          }
        }
      }
    } finally {
      _openingExternal = false;
    }
  }

  Future<void> _load() async {
    try {
      final library = await widget.repository.load();
      if (mounted) {
        setState(() {
          _library = library;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = s['storageError']);
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    String error = 'storageError',
  }) async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s[error])));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import({bool sample = false}) => _run(() async {
    PaperDocument doc;
    if (sample) {
      final data = await rootBundle.load('assets/sample.pdf');
      doc = await widget.repository.importPdf(
        name: 'Welcome to Cave Paper.pdf',
        bytes: Stream.value(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      );
    } else {
      if (!_explainedImport && (_library?.documents.isEmpty ?? true)) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (_) => FileAccessDialog(strings: s),
        );
        if (accepted != true || !mounted) return;
        _explainedImport = true;
      }
      final file = await fs.openFile(
        acceptedTypeGroups: const [
          fs.XTypeGroup(
            label: 'PDF',
            extensions: ['pdf'],
            mimeTypes: ['application/pdf'],
            uniformTypeIdentifiers: ['com.adobe.pdf'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      doc = await widget.repository.importPdf(
        name: file.name,
        bytes: file.openRead(),
      );
    }
    await _load();
    if (mounted) await _read(doc);
  }, error: 'importError');

  Future<void> _read(PaperDocument doc) async {
    await widget.repository.verifyDocument(doc);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          repository: widget.repository,
          document: doc,
          strings: s,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _rename(PaperDocument doc) async {
    final controller = TextEditingController(text: doc.title);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s['rename']),
        content: TextField(
          controller: controller,
          maxLength: 240,
          autofocus: true,
          decoration: InputDecoration(labelText: s['title']),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s['cancel']),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(s['save']),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && mounted) {
      await _run(() async {
        await widget.repository.updateDocument(
          doc.id,
          (d) => d.copyWith(title: name),
        );
        await _load();
      });
    }
  }

  Future<void> _remove(PaperDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s['removeTitle']),
        content: Text(s['removeDetail']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s['cancel']),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s['delete']),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(() async {
        await widget.repository.removeDocument(doc.id);
        widget.thumbnails?.forget(doc.id);
        await _load();
      });
    }
  }

  Future<void> _settings() async {
    if (_settingsOpen) return;
    _settingsOpen = true;
    try {
      var current = widget.settings;
      final result = await showDialog<PaperSettings>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(s['settings']),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Appearance>(
                      isExpanded: true,
                      initialValue: current.appearance,
                      decoration: InputDecoration(labelText: s['appearance']),
                      items: [
                        for (final v in Appearance.values)
                          DropdownMenuItem(
                            value: v,
                            child: Row(
                              children: [
                                Icon(_appearanceIcon(v)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s[v.name],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          update(
                            () => current = current.copyWith(appearance: v),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _appearancePreview(current.appearance),
                    const SizedBox(height: 8),
                    Text(s['libraryAppearanceHint']),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: current.language,
                      decoration: InputDecoration(labelText: s['language']),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          update(() => current = current.copyWith(language: v));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(s['defaultApp']),
                      subtitle: Text(s['defaultAppSubtitle']),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showDefaultApp,
                    ),
                    const SizedBox(height: 12),
                    Text(s['dataFolder']),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.repository.root.path,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(s['cancel']),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, current),
                child: Text(s['save']),
              ),
            ],
          ),
        ),
      );
      if (result != null && mounted) {
        await _run(() async {
          await widget.onSettingsChanged(result);
          await _load();
        });
      }
    } finally {
      _settingsOpen = false;
    }
  }

  IconData _appearanceIcon(Appearance appearance) => switch (appearance) {
    Appearance.system => Icons.brightness_auto_outlined,
    Appearance.light => Icons.light_mode_outlined,
    Appearance.dark => Icons.dark_mode_outlined,
    Appearance.black => Icons.contrast,
  };

  Widget _appearancePreview(Appearance appearance) {
    final palette = appearance == Appearance.system
        ? (MediaQuery.platformBrightnessOf(context) == Brightness.dark
              ? Appearance.dark
              : Appearance.light)
        : appearance;
    final colors = PaperTheme.scheme(palette);
    return Semantics(
      label: s['libraryAppearancePreview'],
      child: Container(
        key: const ValueKey('library-appearance-preview'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(PaperTheme.radiusButton),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s['libraryAppearancePreview'],
                style: TextStyle(color: colors.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLibraryRail() async {
    if (_savingRail || _library == null) return;
    setState(() => _savingRail = true);
    try {
      final next = await widget.repository.setLibraryRailCollapsed(
        !_library!.settings.libraryRailCollapsed,
      );
      if (mounted) setState(() => _library = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s['storageError'])));
      }
    } finally {
      if (mounted) setState(() => _savingRail = false);
    }
  }

  void _about() => showAboutDialog(
    context: context,
    applicationName: s.appName,
    applicationVersion: '0.1.0 beta',
    applicationLegalese: '© 2026 Cave · MIT',
    applicationIcon: Image.asset(
      'assets/branding/app-logo.png',
      width: 40,
      height: 40,
      fit: BoxFit.contain,
    ),
    children: [
      const SizedBox(height: 16),
      Text(s['noAccount']),
      const SizedBox(height: 16),
      Text(s['readOnlyForms']),
      const SizedBox(height: 12),
      Text(s['annotationsDetail']),
    ],
  );

  Widget _navigation({bool compact = false, bool collapsible = false}) =>
      SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: bounds.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(compact ? 16 : 24),
                      child: compact
                          ? Image.asset(
                              'assets/branding/app-logo.png',
                              width: 32,
                              height: 32,
                            )
                          : Row(
                              children: [
                                Image.asset(
                                  'assets/branding/app-logo.png',
                                  width: 32,
                                  height: 32,
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    s.appName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (collapsible)
                      IconButton(
                        tooltip:
                            s[compact
                                ? 'libraryExpandRail'
                                : 'libraryCollapseRail'],
                        onPressed: _savingRail || _library == null
                            ? null
                            : _toggleLibraryRail,
                        icon: Icon(compact ? Icons.menu_open : Icons.menu),
                      ),
                    if (compact)
                      IconButton(
                        tooltip: s['library'],
                        onPressed: () {},
                        icon: const Icon(Icons.folder_open_outlined),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ListTile(
                          selected: true,
                          leading: const Icon(Icons.folder_open_outlined),
                          title: Text(s['library']),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (compact) ...[
                      IconButton(
                        tooltip: s['libraryAppearance'],
                        onPressed: _settings,
                        icon: Icon(_appearanceIcon(widget.settings.appearance)),
                      ),
                      IconButton(
                        tooltip: s['settings'],
                        onPressed: _settings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                      IconButton(
                        tooltip: s['about'],
                        onPressed: _about,
                        icon: const Icon(Icons.info_outline),
                      ),
                    ] else ...[
                      ListTile(
                        leading: Icon(
                          _appearanceIcon(widget.settings.appearance),
                        ),
                        title: Text(s['libraryAppearance']),
                        subtitle: Text(s[widget.settings.appearance.name]),
                        onTap: _settings,
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: Text(s['settings']),
                        onTap: _settings,
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(s['about']),
                        onTap: _about,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          s['privacy'],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  String _size(int bytes) => bytes < 1048576
      ? '${(bytes / 1024).ceil()} KiB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MiB';

  Widget _pdfIcon({double width = 36, double height = 44}) => Image.asset(
    'assets/branding/pdf-icon.png',
    width: width,
    height: height,
    fit: BoxFit.contain,
  );

  /// The document's first page when a preview exists, else the PDF icon.
  Widget _preview(PaperDocument doc, {double width = 36, double height = 44}) {
    final thumbnails = widget.thumbnails;
    if (thumbnails == null) return _pdfIcon(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: FutureBuilder<File?>(
        future: thumbnails.load(doc),
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) return _pdfIcon(width: width, height: height);
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              file,
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _pdfIcon(width: width, height: height),
            ),
          );
        },
      ),
    );
  }

  Widget _continueReading(List<PaperDocument> all) {
    final recent = all.where((d) => d.lastOpenedAt != null).toList()
      ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    // A short library is already one glance; the row helps larger ones.
    if (recent.isEmpty || all.length < 4) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('continue-reading'),
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s['continueReading'],
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 216,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: min(recent.length, 6),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final doc = recent[index];
                return SizedBox(
                  width: 136,
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _busy ? null : () => _run(() => _read(doc)),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: _preview(doc, width: 96, height: 116),
                            ),
                            const SizedBox(height: 8),
                            Flexible(
                              child: Text(
                                doc.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${s['page']} ${doc.lastPage}',
                              maxLines: 1,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String detail, {
    List<Widget> actions = const [],
    String? note,
  }) => SliverFillRemaining(
    hasScrollBody: false,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SizedBox(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(detail, textAlign: TextAlign.center),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: actions,
                ),
              ],
              if (note != null) ...[
                const SizedBox(height: 16),
                Text(
                  note,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  String _folderLabel(DevicePdf pdf) {
    final folder = p.dirname(pdf.path);
    final android = widget.devicePdfs?.platform == 'android';
    for (final root in _deviceRoots) {
      if (p.equals(folder, root)) return android ? '/' : p.basename(root);
      if (p.isWithin(root, folder)) {
        final relative = p.relative(folder, from: root);
        return android ? relative : p.join(p.basename(root), relative);
      }
    }
    return folder;
  }

  List<Widget> _deviceSlivers() {
    final device = widget.devicePdfs!;
    final access = _deviceAccess;
    final result = _deviceResult;
    if (access == null || (_scanning && result == null)) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(s['deviceScanning']),
              ],
            ),
          ),
        ),
      ];
    }
    if (access == DeviceAccess.unavailable) {
      return [
        _message(
          Icons.folder_off_outlined,
          s['viewDevice'],
          s['deviceUnavailable'],
        ),
      ];
    }
    if (access != DeviceAccess.granted) {
      return [
        _message(
          Icons.travel_explore,
          s['deviceAccessTitle'],
          s['deviceAccessDetail'],
          actions: [
            FilledButton.icon(
              key: const ValueKey('device-allow'),
              onPressed: _allowDevice,
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(s['deviceAllow']),
            ),
          ],
          note: access == DeviceAccess.pending
              ? s['devicePending']
              : s['deviceDenied'],
        ),
      ];
    }
    final hasQuery = _query.trim().isNotEmpty;
    if (_deviceRoots.isEmpty) {
      return [
        _message(
          Icons.create_new_folder_outlined,
          s['deviceAddFolder'],
          s['deviceChooseHint'],
          actions: [
            if (device.folderPicker)
              FilledButton.icon(
                onPressed: _scanning ? null : _addFolder,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(s['deviceAddFolder']),
              ),
          ],
        ),
      ];
    }
    final files = deviceListing(
      result?.files ?? const [],
      query: _query,
      byName: _sort == LibrarySort.title,
    );
    final inLibrary = {
      for (final doc in _library?.documents ?? const <PaperDocument>[])
        '${doc.title}\u0000${doc.byteLength}',
    };
    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(s['deviceCount'].replaceAll('{count}', '${files.length}')),
                _sortField(),
                OutlinedButton.icon(
                  onPressed: _scanning ? null : _scanDevice,
                  icon: const Icon(Icons.refresh),
                  label: Text(s['deviceRefresh']),
                ),
                if (device.folderPicker)
                  OutlinedButton.icon(
                    onPressed: _scanning ? null : _addFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: Text(s['deviceAddFolder']),
                  ),
              ],
            ),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (result?.incomplete == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  s['deviceIncomplete'],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              s['deviceOpenHint'],
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
    if (files.isEmpty) {
      return [
        header,
        _message(
          Icons.search_off,
          hasQuery ? s['noMatch'] : s['deviceEmpty'],
          hasQuery
              ? s['librarySearchDetail']
              : (device.platform == 'windows' || device.platform == 'linux'
                    ? s['deviceSearched']
                    : ''),
        ),
      ];
    }
    final dates = MaterialLocalizations.of(context);
    return [
      header,
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        sliver: SliverList.separated(
          itemCount: files.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final pdf = files[index];
            final known = inLibrary.contains('${pdf.name}\u0000${pdf.bytes}');
            return Card(
              child: ListTile(
                key: ValueKey('device-${pdf.path}'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: _pdfIcon(),
                title: Text(
                  pdf.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_folderLabel(pdf)} · ${_size(pdf.bytes)} · ${dates.formatShortDate(pdf.modified)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: known
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            s['deviceInLibrary'],
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      )
                    : null,
                onTap: _busy ? null : () => _openDevicePdf(pdf),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _sortField() => SizedBox(
    width: 220,
    child: DropdownButtonFormField<LibrarySort>(
      initialValue: _sort,
      isExpanded: true,
      decoration: InputDecoration(labelText: s['librarySort']),
      items: [
        for (final sort in LibrarySort.values)
          DropdownMenuItem(value: sort, child: Text(s[sort.label])),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _sort = value);
      },
    ),
  );

  List<Widget> _librarySlivers(
    List<PaperDocument> documents,
    List<PaperDocument> allDocuments,
    bool hasQuery,
  ) => [
    SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasQuery) _continueReading(allDocuments),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  s['libraryResultCount']
                      .replaceAll('{shown}', '${documents.length}')
                      .replaceAll('{total}', '${allDocuments.length}'),
                ),
                _sortField(),
              ],
            ),
          ),
        ],
      ),
    ),
    if (documents.isEmpty)
      _message(
        Icons.description_outlined,
        !hasQuery ? s['empty'] : s['noMatch'],
        !hasQuery ? s['emptyDetail'] : s['librarySearchDetail'],
        actions: [
          if (hasQuery)
            TextButton(
              onPressed: _clearSearch,
              child: Text(s['libraryClearSearch']),
            ),
        ],
      )
    else
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        sliver: SliverList.separated(
          itemCount: documents.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = documents[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                leading: _preview(doc),
                title: Text(
                  doc.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_size(doc.byteLength)} · ${s['page']} ${doc.lastPage} · ${doc.notes.length} ${s['notes']}',
                ),
                onTap: _busy ? null : () => _run(() => _read(doc)),
                trailing: PopupMenuButton<String>(
                  tooltip: s['tools'],
                  onSelected: (v) {
                    if (v == 'rename') unawaited(_rename(doc));
                    if (v == 'remove') unawaited(_remove(doc));
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(s['rename'])),
                    PopupMenuItem(value: 'remove', child: Text(s['delete'])),
                  ],
                ),
              ),
            );
          },
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 960;
      final railCollapsed = _library?.settings.libraryRailCollapsed ?? false;
      final hasQuery = _query.trim().isNotEmpty;
      final allDocuments = _library?.documents ?? <PaperDocument>[];
      final documents = libraryListing(
        allDocuments,
        query: _query,
        sort: _sort,
      );
      final deviceView = _deviceSupported && _view == LibraryView.device;
      final apple =
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS;
      final body = _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: Text(s['retry'])),
                  ],
                ),
              ),
            )
          : _library == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.repository.warning != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: MaterialBanner(
                            content: Text(s[widget.repository.warning!]),
                            actions: [
                              TextButton(
                                onPressed: () => setState(
                                  () => widget.repository.warning = null,
                                ),
                                child: Text(s['close']),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.all(wide ? 32 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              s['library'],
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(s['tagline']),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(() => _query = v),
                              decoration: InputDecoration(
                                labelText: s['searchLibrary'],
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: s['libraryClearSearch'],
                                        onPressed: _clearSearch,
                                        icon: const Icon(Icons.close),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: _busy ? null : () => _import(),
                                  icon: const Icon(Icons.add),
                                  label: Text(s['open']),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _import(sample: true),
                                  icon: const Icon(Icons.auto_stories_outlined),
                                  label: Text(s['sample']),
                                ),
                              ],
                            ),
                            if (_deviceSupported) ...[
                              const SizedBox(height: 20),
                              SegmentedButton<LibraryView>(
                                key: const ValueKey('library-view'),
                                showSelectedIcon: false,
                                segments: [
                                  ButtonSegment(
                                    value: LibraryView.library,
                                    icon: const Icon(
                                      Icons.collections_bookmark_outlined,
                                    ),
                                    label: Text(s['viewLibrary']),
                                  ),
                                  ButtonSegment(
                                    value: LibraryView.device,
                                    icon: Icon(
                                      widget.devicePdfs!.platform == 'android'
                                          ? Icons.smartphone_outlined
                                          : Icons.computer_outlined,
                                    ),
                                    label: Text(s['viewDevice']),
                                  ),
                                ],
                                selected: {_view},
                                onSelectionChanged: (value) =>
                                    unawaited(_showView(value.first)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Kept in the first sliver so it is always on screen.
                      if (_busy) const LinearProgressIndicator(),
                    ],
                  ),
                ),
                if (deviceView)
                  ..._deviceSlivers()
                else
                  ..._librarySlivers(documents, allDocuments, hasQuery),
              ],
            );
      return CallbackShortcuts(
        bindings: {
          SingleActivator(
            LogicalKeyboardKey.keyO,
            meta: apple,
            control: !apple,
          ): () {
            if (!_busy) unawaited(_import());
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: wide
                ? null
                : AppBar(
                    title: Text(s.appName),
                    actions: [
                      IconButton(
                        tooltip: s['libraryAppearance'],
                        onPressed: _settings,
                        icon: Icon(_appearanceIcon(widget.settings.appearance)),
                      ),
                    ],
                  ),
            drawer: wide ? null : Drawer(child: _navigation()),
            body: Row(
              children: [
                if (wide)
                  SizedBox(
                    width: railCollapsed ? 72 : 244,
                    child: _navigation(
                      compact: railCollapsed,
                      collapsible: true,
                    ),
                  ),
                if (wide) const VerticalDivider(width: 1),
                Expanded(child: SafeArea(child: body)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
