import 'dart:async';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/library_repository.dart';
import '../domain/library.dart';
import 'reader_screen.dart';
import 'strings.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({required this.repository, required this.settings,
    required this.onSettingsChanged, required this.strings, super.key});
  final LibraryRepository repository;
  final PaperSettings settings;
  final Future<void> Function(PaperSettings) onSettingsChanged;
  final PaperStrings strings;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  PaperLibrary? _library;
  bool _busy = false;
  String? _error;
  String _query = '';
  PaperStrings get s => widget.strings;
  @override
  void initState() { super.initState(); unawaited(_load()); }
  Future<void> _load() async {
    try {
      final library = await widget.repository.load();
      if (mounted) setState(() { _library = library; _error = null; });
    } catch (_) { if (mounted) setState(() => _error = s['storageError']); }
  }
  Future<void> _run(Future<void> Function() action, {String error = 'storageError'}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await action(); } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s[error])));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _import({bool sample = false}) => _run(() async {
    PaperDocument doc;
    if (sample) {
      final data = await rootBundle.load('assets/sample.pdf');
      doc = await widget.repository.importPdf(name: 'Welcome to Cave Paper.pdf',
        bytes: Stream.value(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
    } else {
      final file = await fs.openFile(acceptedTypeGroups: const [fs.XTypeGroup(
        label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf'],
        uniformTypeIdentifiers: ['com.adobe.pdf'])]);
      if (file == null) return;
      doc = await widget.repository.importPdf(name: file.name, bytes: file.openRead());
    }
    await _load();
    if (mounted) await _read(doc);
  }, error: 'importError');

  Future<void> _read(PaperDocument doc) async {
    await widget.repository.verifyDocument(doc);
    if (!mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) =>
      ReaderScreen(repository: widget.repository, document: doc, strings: s)));
    if (mounted) await _load();
  }
  Future<void> _rename(PaperDocument doc) async {
    final controller = TextEditingController(text: doc.title);
    final name = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: Text(s['rename']), content: TextField(controller: controller,
        maxLength: 240, autofocus: true, decoration: InputDecoration(labelText: s['title'])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(s['cancel'])),
        FilledButton(onPressed: () {
          if (controller.text.trim().isNotEmpty) Navigator.pop(context, controller.text.trim());
        }, child: Text(s['save']))]));
    controller.dispose();
    if (name != null) await _run(() async {
      await widget.repository.updateDocument(doc.id, (d) => d.copyWith(title: name));
      await _load();
    });
  }
  Future<void> _remove(PaperDocument doc) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(s['removeTitle']), content: Text(s['removeDetail']), actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s['cancel'])),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s['delete']))]));
    if (confirmed == true) await _run(() async {
      await widget.repository.removeDocument(doc.id); await _load();
    });
  }
  Future<void> _settings() async {
    var current = widget.settings;
    final result = await showDialog<PaperSettings>(context: context,
      builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
        title: Text(s['settings']), content: SizedBox(width: 420, child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<Appearance>(initialValue: current.appearance,
            decoration: InputDecoration(labelText: s['appearance']),
            items: [for (final v in Appearance.values) DropdownMenuItem(value: v, child: Text(s[v.name]))],
            onChanged: (v) { if (v != null) update(() => current = current.copyWith(appearance: v)); }),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(initialValue: current.language,
            decoration: InputDecoration(labelText: s['language']), items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ar', child: Text('العربية'))],
            onChanged: (v) { if (v != null) update(() => current = current.copyWith(language: v)); }),
          const SizedBox(height: 24), Text(s['dataFolder']), const SizedBox(height: 8),
          SelectableText(widget.repository.root.path, textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodySmall),
        ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(s['cancel'])),
          FilledButton(onPressed: () => Navigator.pop(context, current), child: Text(s['save']))])));
    if (result != null) await _run(() async { await widget.onSettingsChanged(result); await _load(); });
  }
  void _about() => showAboutDialog(context: context, applicationName: s.appName,
    applicationVersion: '0.1.0 beta', applicationLegalese: '© 2026 Cave · MIT',
    applicationIcon: const Icon(Icons.auto_stories_outlined, size: 40),
    children: [const SizedBox(height: 16), Text(s['noAccount']),
      const SizedBox(height: 16), Text(s['readOnlyForms']),
      const SizedBox(height: 12), Text(s['annotationsDetail'])]);

  Widget _navigation() => SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.all(24), child: Row(children: [
      Icon(Icons.auto_stories_outlined, color: Theme.of(context).colorScheme.primary, size: 32),
      const SizedBox(width: 12), Flexible(child: Text(s.appName,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)))])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ListTile(
      selected: true, leading: const Icon(Icons.folder_open_outlined), title: Text(s['library']),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    const Spacer(),
    ListTile(leading: const Icon(Icons.settings_outlined), title: Text(s['settings']), onTap: _settings),
    ListTile(leading: const Icon(Icons.info_outline), title: Text(s['about']), onTap: _about),
    Padding(padding: const EdgeInsets.all(24), child: Text(s['privacy'],
      style: Theme.of(context).textTheme.bodySmall)),
  ]));
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final wide = constraints.maxWidth >= 960;
    final documents = (_library?.documents ?? []).where((d) =>
      d.title.toLowerCase().contains(_query.toLowerCase())).toList()
      ..sort((a, b) => (b.lastOpenedAt ?? b.importedAt).compareTo(a.lastOpenedAt ?? a.importedAt));
    final body = _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child:
      Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 16),
        FilledButton(onPressed: _load, child: Text(s['retry']))])))
      : _library == null ? const Center(child: CircularProgressIndicator())
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.repository.warning != null) Padding(padding: const EdgeInsets.all(16), child:
          MaterialBanner(content: Text(s[widget.repository.warning!]), actions: [
            TextButton(onPressed: () => setState(() => widget.repository.warning = null), child: Text(s['close']))])),
        Padding(padding: EdgeInsets.all(wide ? 32 : 20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s['library'], style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6), Text(s['tagline']), const SizedBox(height: 24),
          TextField(onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(labelText: s['searchLibrary'], prefixIcon: const Icon(Icons.search))),
          const SizedBox(height: 16), Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton.icon(onPressed: _busy ? null : () => _import(),
              icon: const Icon(Icons.add), label: Text(s['open'])),
            OutlinedButton.icon(onPressed: _busy ? null : () => _import(sample: true),
              icon: const Icon(Icons.auto_stories_outlined), label: Text(s['sample']))]),
        ])),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: documents.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.description_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20), Text(_query.isEmpty ? s['empty'] : s['noMatch'],
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12), Text(s['emptyDetail'], textAlign: TextAlign.center),
          ]))) : ListView.separated(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: documents.length, separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = documents[index];
            return Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: const Icon(Icons.picture_as_pdf_outlined, size: 36),
              title: Text(doc.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${(doc.byteLength / 1048576).toStringAsFixed(1)} MiB · ${s['page']} ${doc.lastPage} · ${doc.notes.length} ${s['notes']}'),
              onTap: _busy ? null : () => _run(() => _read(doc)),
              trailing: PopupMenuButton<String>(tooltip: s['tools'], onSelected: (v) {
                if (v == 'rename') unawaited(_rename(doc));
                if (v == 'remove') unawaited(_remove(doc));
              }, itemBuilder: (_) => [PopupMenuItem(value: 'rename', child: Text(s['rename'])),
                PopupMenuItem(value: 'remove', child: Text(s['delete']))])));
          })),
      ]);
    return Scaffold(appBar: wide ? null : AppBar(title: Text(s.appName)),
      drawer: wide ? null : Drawer(child: _navigation()),
      body: Row(children: [if (wide) SizedBox(width: 244, child: _navigation()),
        if (wide) const VerticalDivider(width: 1), Expanded(child: SafeArea(child: body))]));
  });
}
