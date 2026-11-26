// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/library_repository.dart';
import '../domain/library.dart';
import '../domain/page_edit.dart';
import '../services/page_assembly.dart';
import 'strings.dart';

/// Reorder, rotate, delete, extract and merge pages. Nothing is written until
/// the person saves; the result is a new library document and every original
/// stays exactly as it was.
class PageEditorScreen extends StatefulWidget {
  const PageEditorScreen({
    required this.repository,
    required this.document,
    required this.strings,
    this.assembly,
    super.key,
  });
  final LibraryRepository repository;
  final PaperDocument document;
  final PaperStrings strings;
  final PageAssembly? assembly;

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  final _sources = <String, PdfDocument>{};
  final _titles = <String, String>{};
  final _undo = <PageEditPlan>[];
  Set<int> _selected = {};
  PageEditPlan? _plan;
  String? _error;
  bool _busy = false;
  PaperStrings get s => widget.strings;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    for (final pdf in _sources.values) {
      unawaited(pdf.dispose());
    }
    super.dispose();
  }

  /// Opens a library PDF for previews and returns its page count, or null when
  /// it is protected and cannot be assembled.
  Future<int?> _open(PaperDocument document) async {
    final existing = _sources[document.id];
    if (existing != null) return existing.pages.length;
    await widget.repository.verifyDocument(document);
    await pdfrxFlutterInitialize();
    final PdfDocument pdf;
    try {
      pdf = await PdfDocument.openFile(
        widget.repository.documentFile(document.id).path,
        passwordProvider: () async => null,
      );
    } on PdfPasswordException {
      return null;
    }
    if (pdf.isEncrypted ||
        (pdf.permissions != null && !pdf.permissions!.allowsDocumentAssembly) ||
        pdf.pages.isEmpty) {
      await pdf.dispose();
      return null;
    }
    if (!mounted) {
      await pdf.dispose();
      return null;
    }
    _sources[document.id] = pdf;
    _titles[document.id] = document.title;
    return pdf.pages.length;
  }

  Future<void> _start() async {
    try {
      final count = await _open(widget.document);
      if (!mounted) return;
      setState(() {
        if (count == null) {
          _error = s['editProtected'];
        } else {
          _plan = PageEditPlan.of(widget.document.id, count);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = s['loadFailed']);
    }
  }

  void _change(PageEditPlan next, {Set<int>? selected}) {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _undo.add(plan);
      if (_undo.length > 100) _undo.removeAt(0);
      _plan = next;
      _selected =
          selected ??
          {
            for (final p in next.pages)
              if (_selected.contains(p.key)) p.key,
          };
    });
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() {
      _plan = _undo.removeLast();
      _selected = {};
    });
  }

  bool get _changed {
    final plan = _plan;
    if (plan == null) return false;
    final count = _sources[widget.document.id]?.pages.length ?? 0;
    return !plan.isOriginal(widget.document.id, count);
  }

  void _show(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s[key])));
  }

  Future<void> _addPdf() async {
    final plan = _plan;
    if (plan == null || _busy) return;
    final library = await widget.repository.load();
    if (!mounted) return;
    const fromFile = '\u0000file';
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(s['editAddPdf']),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, fromFile),
            child: ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(s['editAddFromFile']),
            ),
          ),
          for (final doc in library.documents)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, doc.id),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(
                  doc.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      PaperDocument? document;
      if (choice == fromFile) {
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
        if (file == null) return;
        document = await widget.repository.importPdf(
          name: file.name,
          bytes: file.openRead(),
        );
      } else {
        document = library.find(choice);
      }
      if (document == null || !mounted) return;
      final count = await _open(document);
      if (!mounted) return;
      if (count == null) {
        _show('editProtected');
        return;
      }
      _change(_plan!.append(document.id, count), selected: {});
    } on LibraryFormatException {
      _show('editTooMany');
    } catch (_) {
      _show('importError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final plan = _plan;
    if (plan == null || plan.isEmpty || _busy) return;
    final field = TextEditingController(
      text: editedTitle(widget.document.title, s['editedSuffix']),
    );
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s['editSave']),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s['editSaveDetail']),
              const SizedBox(height: 16),
              TextField(
                controller: field,
                autofocus: true,
                decoration: InputDecoration(labelText: s['editFileName']),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s['cancel']),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: Text(s['save']),
          ),
        ],
      ),
    );
    field.dispose();
    if (title == null || title.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final saved = await (widget.assembly ?? PageAssembly()).saveToLibrary(
        repository: widget.repository,
        plan: plan,
        title: title.toLowerCase().endsWith('.pdf') ? title : '$title.pdf',
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (_) {
      _show('editSaveError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_changed || _busy) return !_busy;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s['editDiscardTitle']),
        content: Text(s['editDiscardDetail']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s['editKeepEditing']),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s['editDiscard']),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Widget _thumb(EditedPage page) {
    final pdf = _sources[page.documentId];
    return SizedBox(
      width: 56,
      height: 72,
      child: pdf == null
          ? const Icon(Icons.picture_as_pdf_outlined)
          : RotatedBox(
              quarterTurns: page.turns,
              child: PdfPageView(
                key: ValueKey((page.documentId, page.page)),
                document: pdf,
                pageNumber: page.page,
                maximumDpi: 48,
                backgroundColor: Colors.white,
              ),
            ),
    );
  }

  Widget _toolbar(PageEditPlan plan) {
    final selected = _selected;
    final any = selected.isNotEmpty;
    final keys = any ? selected : <int>{};
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: any
            ? [
                Text(
                  s['editSelected'].replaceAll('{count}', '${selected.length}'),
                ),
                IconButton(
                  tooltip: s['editRotateLeft'],
                  onPressed: () => _change(plan.rotate(keys, 3)),
                  icon: const Icon(Icons.rotate_left),
                ),
                IconButton(
                  tooltip: s['editRotateRight'],
                  onPressed: () => _change(plan.rotate(keys, 1)),
                  icon: const Icon(Icons.rotate_right),
                ),
                IconButton(
                  tooltip: s['editDelete'],
                  onPressed: () => _change(plan.remove(keys), selected: {}),
                  icon: const Icon(Icons.delete_outline),
                ),
                OutlinedButton.icon(
                  onPressed: () => _change(plan.keepOnly(keys), selected: {}),
                  icon: const Icon(Icons.content_cut),
                  label: Text(s['editKeepSelected']),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected = {}),
                  child: Text(s['editClearSelection']),
                ),
              ]
            : [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _addPdf,
                  icon: const Icon(Icons.library_add_outlined),
                  label: Text(s['editAddPdf']),
                ),
                OutlinedButton.icon(
                  onPressed: plan.length > 1
                      ? () => _change(plan.reversed())
                      : null,
                  icon: const Icon(Icons.swap_vert),
                  label: Text(s['editReverse']),
                ),
                TextButton(
                  onPressed: plan.isEmpty
                      ? null
                      : () => setState(
                          () => _selected = {for (final p in plan.pages) p.key},
                        ),
                  child: Text(s['editSelectAll']),
                ),
              ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(s['editPages']),
          actions: [
            IconButton(
              tooltip: s['editUndo'],
              onPressed: _undo.isEmpty || _busy ? null : _undoLast,
              icon: const Icon(Icons.undo),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: FilledButton(
                key: const ValueKey('edit-save'),
                onPressed: plan == null || plan.isEmpty || _busy || !_changed
                    ? null
                    : _save,
                child: Text(s['editSave']),
              ),
            ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : plan == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      s['editHint'],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  _toolbar(plan),
                  Expanded(
                    child: plan.isEmpty
                        ? Center(child: Text(s['editEmpty']))
                        : ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: plan.length,
                            onReorderItem: (from, to) =>
                                _change(plan.move(from, to)),
                            itemBuilder: (context, index) => _row(plan, index),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _row(PageEditPlan plan, int index) {
    final page = plan.pages[index];
    final selected = _selected.contains(page.key);
    final merged = plan.documentIds.length > 1;
    final source = merged
        ? '${_titles[page.documentId] ?? ''} · ${s['page']} ${page.page}'
        : '${s['editOriginalPage']} ${page.page}';
    void toggle() => setState(() {
      _selected = {..._selected};
      if (!_selected.remove(page.key)) _selected.add(page.key);
    });
    return Card(
      key: ValueKey(page.key),
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(8, 4, 4, 4),
        selected: selected,
        onTap: toggle,
        onLongPress: toggle,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: selected, onChanged: (_) => toggle()),
            _thumb(page),
          ],
        ),
        title: Text('${s['page']} ${index + 1}'),
        subtitle: Text(
          page.turns == 0 ? source : '$source · ${page.turns * 90}°',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: s['editRotateRight'],
              onPressed: () => _change(plan.rotate({page.key}, 1)),
              icon: const Icon(Icons.rotate_right),
            ),
            IconButton(
              tooltip: s['editDelete'],
              onPressed: () => _change(plan.remove({page.key})),
              icon: const Icon(Icons.delete_outline),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.drag_handle, semanticLabel: s['editDrag']),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
