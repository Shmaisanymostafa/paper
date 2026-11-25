// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/external_documents.dart';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/library_repository.dart';
import '../domain/library.dart';
import 'reader_screen.dart';
import '../domain/library_listing.dart';
import 'strings.dart';
import 'file_access_dialog.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.repository,
    required this.settings,
    required this.onSettingsChanged,
    required this.strings,
    super.key,
  });
  final LibraryRepository repository;
  final PaperSettings settings;
  final Future<void> Function(PaperSettings) onSettingsChanged;
  final PaperStrings strings;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
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
    unawaited(_load());
    unawaited(_startExternal());
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
                    const SizedBox(height: 24),
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
  };

  Widget _appearancePreview(Appearance appearance) {
    final dark =
        appearance == Appearance.dark ||
        (appearance == Appearance.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF147F79),
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return Semantics(
      label: s['libraryAppearancePreview'],
      child: Container(
        key: const ValueKey('library-appearance-preview'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF10232C) : const Color(0xFFF5F7F6),
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(12),
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
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          0,
                          20,
                          12,
                        ),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              s['libraryResultCount']
                                  .replaceAll('{shown}', '${documents.length}')
                                  .replaceAll(
                                    '{total}',
                                    '${allDocuments.length}',
                                  ),
                            ),
                            SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<LibrarySort>(
                                initialValue: _sort,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: s['librarySort'],
                                ),
                                items: [
                                  for (final sort in LibrarySort.values)
                                    DropdownMenuItem(
                                      value: sort,
                                      child: Text(s[sort.label]),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _sort = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_busy) const LinearProgressIndicator(),
                    ],
                  ),
                ),
                if (documents.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 72,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              !hasQuery ? s['empty'] : s['noMatch'],
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              !hasQuery
                                  ? s['emptyDetail']
                                  : s['librarySearchDetail'],
                              textAlign: TextAlign.center,
                            ),
                            if (hasQuery)
                              TextButton(
                                onPressed: _clearSearch,
                                child: Text(s['libraryClearSearch']),
                              ),
                          ],
                        ),
                      ),
                    ),
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
                            leading: Image.asset(
                              'assets/branding/pdf-icon.png',
                              width: 36,
                              height: 44,
                              fit: BoxFit.contain,
                            ),
                            title: Text(
                              doc.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${(doc.byteLength / 1048576).toStringAsFixed(1)} MiB · ${s['page']} ${doc.lastPage} · ${doc.notes.length} ${s['notes']}',
                            ),
                            onTap: _busy ? null : () => _run(() => _read(doc)),
                            trailing: PopupMenuButton<String>(
                              tooltip: s['tools'],
                              onSelected: (v) {
                                if (v == 'rename') unawaited(_rename(doc));
                                if (v == 'remove') unawaited(_remove(doc));
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text(s['rename']),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(s['delete']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
      return Scaffold(
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
                child: _navigation(compact: railCollapsed, collapsible: true),
              ),
            if (wide) const VerticalDivider(width: 1),
            Expanded(child: SafeArea(child: body)),
          ],
        ),
      );
    },
  );
}
