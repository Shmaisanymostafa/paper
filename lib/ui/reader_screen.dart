import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../data/library_repository.dart';
import '../domain/library.dart';
import '../domain/note_changes.dart';
import '../services/document_share.dart';
import '../services/document_print.dart';
import '../services/page_copy.dart';
import 'strings.dart';
import 'page_navigation.dart';
import 'page_copy_dialog.dart';
import 'reader_focus_frame.dart';
import 'note_editor_dialog.dart';
import 'reader_panel_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    required this.repository,
    required this.document,
    required this.strings,
    super.key,
  });
  final LibraryRepository repository;
  final PaperDocument document;
  final PaperStrings strings;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  final _controller = PdfViewerController();
  final _documentShare = DocumentShare();
  bool _sharing = false, _printing = false, _copyingPages = false;
  int _pinnedTools = 0;
  bool _pinsReady = false, _customizing = false, _focusMode = false;
  bool _encrypted = true, _allowsPrinting = false, _uniformPages = false;
  double _printWidth = 0, _printHeight = 0;
  final _documentPrint = DocumentPrint();
  final _searchField = TextEditingController();
  final _panelChanges = ValueNotifier<int>(0);
  late PaperDocument _document;
  PaperNote? _removedNote;
  int _removedNoteIndex = 0;
  bool _undoingNote = false;
  PdfTextSearchSession? _searcher;
  List<PdfOutlineNode> _outline = [];
  List<PdfPageTextRange> _selection = [];
  Timer? _pageTimer;
  int _page = 1, _pageCount = 0, _reload = 0, _tab = 0, _selectionVersion = 0;
  bool _panelVisible = true, _saving = false, _closing = false;
  bool _panelChangedLocally = false;
  PaperStrings get s => widget.strings;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _page = _document.lastPage;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadPins());
  }

  Future<void> _loadPins() => _safely(() async {
    final state = await widget.repository.load();
    if (mounted) {
      setState(() {
        _pinnedTools = state.settings.pinnedTools;
        if (!_panelChangedLocally) {
          _panelVisible = state.settings.readerPanelVisible;
        }
        _pinsReady = true;
      });
    }
  });

  void _setPanelVisible(bool visible) {
    _panelChangedLocally = true;
    setState(() => _panelVisible = visible);
    unawaited(
      _safely(() async {
        await widget.repository.setReaderPanelVisible(visible);
      }),
    );
  }

  List<_ReaderTool> get _tools => [
    const _ReaderTool('note', 'newNote', Icons.sticky_note_2_outlined, 1),
    const _ReaderTool('highlight', 'highlight', Icons.highlight, 2),
    const _ReaderTool('contents', 'outline', Icons.format_list_bulleted, 4),
    const _ReaderTool('notes', 'notes', Icons.notes, 8),
    if (DocumentPrint.supported)
      const _ReaderTool('print', 'printDocument', Icons.print_outlined, 16),
    if (DocumentShare.supported)
      const _ReaderTool('share', 'shareDocument', Icons.share_outlined, 32),
    const _ReaderTool('export', 'export', Icons.file_upload_outlined, 64),
    const _ReaderTool(
      'import',
      'importNotes',
      Icons.file_download_outlined,
      128,
    ),
  ];

  bool _toolEnabled(_ReaderTool tool) =>
      _pageCount > 0 &&
      !(tool.id == 'print' && _printing) &&
      !(tool.id == 'share' && _sharing);

  Future<void> _customizeToolbar() async {
    if (_customizing || !_pinsReady) return;
    setState(() => _customizing = true);
    var selected = _pinnedTools;
    try {
      final result = await showDialog<int>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: Text(s['toolbarCustomize']),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s['toolbarDetail']),
                    for (final tool in _tools)
                      CheckboxListTile(
                        title: Text(s[tool.label]),
                        secondary: Icon(tool.icon),
                        value: (selected & tool.bit) != 0,
                        onChanged: (checked) => refresh(() {
                          selected = checked == true
                              ? selected | tool.bit
                              : selected & ~tool.bit;
                        }),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(s['cancel']),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: Text(s['save']),
              ),
            ],
          ),
        ),
      );
      if (result == null || !mounted) return;
      final state = await widget.repository.setPinnedTools(result);
      if (mounted) setState(() => _pinnedTools = state.settings.pinnedTools);
    } catch (_) {
      _message('storageError');
    } finally {
      if (mounted) setState(() => _customizing = false);
    }
  }

  void _selectTool(String value) {
    switch (value) {
      case 'focus':
        setState(() => _focusMode = true);
      case 'copyPages':
        unawaited(_copyPages());
      case 'customize':
        unawaited(_customizeToolbar());
      case 'note':
        unawaited(_addNote());
      case 'highlight':
        unawaited(_highlight());
      case 'contents':
        _openPanel(1);
      case 'notes':
        _openPanel(3);
      case 'print':
        unawaited(_printDocument());
      case 'share':
        unawaited(_shareDocument());
      case 'export':
        unawaited(_export());
      case 'import':
        unawaited(_importNotes());
      case 'info':
        unawaited(
          showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(s['limitations']),
              content: Text(s['readOnlyForms']),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s['close']),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _toolLabel(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 12),
      Flexible(child: Text(s[label])),
    ],
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageTimer?.cancel();
    _searcher?.removeListener(_refreshSearch);
    _searcher?.dispose();
    _searchField.dispose();
    _panelChanges.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _pageTimer?.cancel();
      unawaited(_savePage());
    }
  }

  void _refreshSearch() {
    if (mounted) {
      setState(() {});
      _panelChanges.value++;
    }
  }

  void _message(String key) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s[key])));
    }
  }

  Future<void> _update(PaperDocument Function(PaperDocument) change) async {
    if (mounted) setState(() => _saving = true);
    try {
      final library = await widget.repository.updateDocument(
        _document.id,
        change,
      );
      if (mounted) {
        setState(() => _document = library.find(_document.id)!);
        _panelChanges.value++;
        if (_controller.isReady) _controller.invalidate();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _safely(
    Future<void> Function() action, {
    String error = 'storageError',
  }) async {
    try {
      await action();
    } catch (_) {
      _message(error);
    }
  }

  Future<void> _savePage() async {
    if (_pageCount == 0) return;
    final page = _page.clamp(1, _pageCount).toInt();
    await _safely(() => _update((doc) => doc.copyWith(lastPage: page)));
  }

  Future<void> _ready(
    PdfDocument document,
    PdfViewerController controller,
  ) async {
    final version = _reload;
    _searcher?.removeListener(_refreshSearch);
    _searcher?.dispose();
    _searcher = PdfTextSearchSession(controller)..addListener(_refreshSearch);
    if (!mounted) return;
    setState(() {
      _printWidth = document.pages.isEmpty ? 0 : document.pages.first.width;
      _printHeight = document.pages.isEmpty ? 0 : document.pages.first.height;
      _uniformPages =
          document.pages.isNotEmpty &&
          document.pages.every(
            (page) =>
                (page.width - _printWidth).abs() < 0.1 &&
                (page.height - _printHeight).abs() < 0.1,
          );
      _encrypted = document.isEncrypted;
      _allowsPrinting = document.permissions?.allowsPrinting ?? true;
      _pageCount = document.pages.length;
      _page = _document.lastPage.clamp(1, max(1, _pageCount)).toInt();
    });
    await _safely(
      () =>
          _update((doc) => doc.copyWith(lastOpenedAt: DateTime.now().toUtc())),
    );
    try {
      final outline = await document.loadOutline();
      if (mounted && version == _reload) setState(() => _outline = outline);
    } catch (_) {
      if (mounted && version == _reload) setState(() => _outline = []);
    }
  }

  void _pageChanged(int? page) {
    if (page == null || !mounted) return;
    // Viewer callbacks can occur during its own build.
    scheduleMicrotask(() {
      if (!mounted) return;
      setState(() => _page = page);
      _pageTimer?.cancel();
      _pageTimer = Timer(
        const Duration(milliseconds: 500),
        () => unawaited(_savePage()),
      );
    });
  }

  Future<void> _bookmark() {
    final page = _page;
    return _safely(
      () => _update(
        (doc) => doc.copyWith(
          bookmarks: doc.bookmarks.contains(page)
              ? doc.bookmarks.where((p) => p != page).toList()
              : [...doc.bookmarks, page],
        ),
      ),
    );
  }

  Future<void> _closeReader() async {
    if (_closing) return;
    _closing = true;
    _pageTimer?.cancel();
    final route = ModalRoute.of(context);
    try {
      await _savePage();
      // Another route may have opened while persistence was pending.
      if (mounted && route?.isCurrent == true) Navigator.of(context).pop();
    } finally {
      _closing = false;
    }
  }

  Future<void> _addNote() async {
    final page = _page;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => NoteEditorDialog(
        title: '${s['newNote']} · ${s['page']} $page',
        strings: s,
      ),
    );
    if (text == null || !mounted) return;
    await _safely(
      () => _update(
        (doc) => doc.copyWith(
          notes: [
            ...doc.notes,
            PaperNote(
              id: _noteId(),
              page: page,
              text: text,
              createdAt: DateTime.now().toUtc(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(PaperNote note) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => NoteEditorDialog(
        title: '${s['readerEditNote']} · ${s['page']} ${note.page}',
        strings: s,
        initialText: note.text,
        allowEmpty: note.boxes.isNotEmpty,
      ),
    );
    if (text == null || !mounted || text == note.text) return;
    await _safely(
      () => _update((doc) => NoteChanges.edit(doc, note, text)),
      error: 'readerNoteConflict',
    );
  }

  Future<void> _removeNote(PaperNote note) async {
    final index = _document.notes.indexWhere((n) => n.id == note.id);
    try {
      await _update((doc) => NoteChanges.remove(doc, note));
      if (!mounted) return;
      setState(() {
        _removedNote = note;
        _removedNoteIndex = index;
      });
      _panelChanges.value++;
    } catch (_) {
      _message('readerNoteConflict');
    }
  }

  Future<void> _undoNoteRemoval() async {
    final note = _removedNote;
    final index = _removedNoteIndex;
    if (note == null || _undoingNote) return;
    setState(() => _undoingNote = true);
    _panelChanges.value++;
    try {
      await _update((doc) => NoteChanges.restore(doc, note, index));
      if (mounted && _removedNote?.id == note.id) {
        setState(() => _removedNote = null);
      }
    } catch (_) {
      _message('readerNoteConflict');
    } finally {
      if (mounted) {
        setState(() => _undoingNote = false);
        _panelChanges.value++;
      }
    }
  }

  Future<void> _highlight() async {
    if (_selection.isEmpty) {
      _message('selectFirst');
      return;
    }
    final selections = List<PdfPageTextRange>.of(_selection);
    await _safely(
      () => _update((doc) {
        final notes = <PaperNote>[];
        for (final range in selections) {
          final rects = range.pageText.fragments.isEmpty
              ? [range.bounds]
              : range
                    .enumerateFragmentBoundingRects()
                    .map((fragment) => fragment.bounds)
                    .toList();
          final boxes = rects
              .where((r) => r.isNotEmpty && r.left >= 0 && r.bottom >= 0)
              .map((r) => HighlightBox(r.left, r.top, r.right, r.bottom))
              .toList();
          if (boxes.isEmpty) continue;
          notes.add(
            PaperNote(
              id: _noteId(),
              page: range.pageNumber,
              text: range.text.length > 10000
                  ? range.text.substring(0, 10000)
                  : range.text,
              boxes: boxes,
              createdAt: DateTime.now().toUtc(),
            ),
          );
        }
        return doc.copyWith(notes: [...doc.notes, ...notes]);
      }),
    );
    _selection = [];
  }

  void _paintNotes(Canvas canvas, Rect pageRect, PdfPage page) {
    final paint = Paint()..color = const Color(0x66FFC940);
    for (final note in _document.notes.where(
      (n) => n.page == page.pageNumber,
    )) {
      for (final b in note.boxes) {
        final rect = PdfRect(
          b.left,
          b.top,
          b.right,
          b.bottom,
        ).toRectInDocument(page: page, pageRect: pageRect).intersect(pageRect);
        if (!rect.isEmpty) canvas.drawRect(rect, paint);
      }
    }
  }

  Future<String?> _password() async {
    if (!mounted) return null;
    final field = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s['password']),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s['passwordDetail']),
              const SizedBox(height: 20),
              TextField(
                controller: field,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                autofocus: true,
                onSubmitted: (v) => Navigator.pop(context, v),
                decoration: InputDecoration(labelText: s['passwordLabel']),
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
            onPressed: () => Navigator.pop(context, field.text),
            child: Text(s['unlock']),
          ),
        ],
      ),
    );
    field.clear();
    field.dispose();
    return password;
  }

  Future<void> _link(PdfLink link) async {
    if (link.dest != null) {
      await _controller.goToDest(link.dest);
      return;
    }
    final url = link.url;
    if (url == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s['blockedLink']),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s['linkDetail']),
              const SizedBox(height: 16),
              SelectableText(url.toString(), textDirection: TextDirection.ltr),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s['close']),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url.toString()));
              if (context.mounted) Navigator.pop(context);
              _message('copied');
            },
            child: Text(s['copy']),
          ),
        ],
      ),
    );
  }

  Future<void> _goTo() async {
    final field = TextEditingController(text: '$_page');
    String? error;
    final number = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(s['goTo']),
          content: TextField(
            controller: field,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${s['page']} (1–$_pageCount)',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s['cancel']),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(field.text);
                if (n == null || n < 1 || n > _pageCount) {
                  update(() => error = s['invalidPage']);
                  return;
                }
                Navigator.pop(context, n);
              },
              child: Text(s['goTo']),
            ),
          ],
        ),
      ),
    );
    field.dispose();
    if (number != null && _controller.isReady) {
      await _controller.goToPage(pageNumber: number);
    }
  }

  Future<void> _printDocument() async {
    if (_printing || !_controller.isReady) return;
    if (_encrypted || !_allowsPrinting) {
      _message('printProtected');
      return;
    }
    setState(() => _printing = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s['printDocument']),
          content: SingleChildScrollView(child: Text(s['printDetail'])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s['cancel']),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s['openPrintDialog']),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || _closing) return;
      await _documentPrint.print(
        repository: widget.repository,
        document: _document,
        encrypted: _encrypted,
        pageWidth: _printWidth,
        pageHeight: _printHeight,
        uniformPages: _uniformPages,
        allowsPrinting: _allowsPrinting,
        isActive: () => mounted && !_closing,
      );
    } on DocumentPrintException catch (error) {
      _message(error.messageKey);
    } catch (_) {
      _message('printError');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _shareDocument() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final includeNotes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s['shareDocument']),
          content: SingleChildScrollView(child: Text(s['shareDetail'])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s['cancel']),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s['pdfOnly']),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s['pdfAndNotes']),
            ),
          ],
        ),
      );
      if (includeNotes == null || !mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      // A valid anchor is required by the iPad and macOS native popover.
      final origin = box.localToGlobal(Offset.zero) & box.size;
      await _documentShare.share(
        repository: widget.repository,
        document: _document,
        origin: origin,
        includeAnnotations: includeNotes,
        isActive: () => mounted && !_closing,
      );
    } catch (_) {
      _message('shareError');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copyPages() async {
    if (_copyingPages || _pageCount == 0) return;
    setState(() => _copyingPages = true);
    try {
      final text = await showDialog<String>(
        context: context,
        builder: (_) =>
            PageCopyDialog(page: _page, pageCount: _pageCount, strings: s),
      );
      if (text == null || !mounted) return;
      final pages = PageCopy.validateSelection(
        text.split(',').map((v) => int.parse(v.trim())),
        _pageCount,
      );
      final target = await fs.getSaveLocation(suggestedName: 'pages-copy.pdf');
      if (target == null || !mounted) return;
      final bytes = await PageCopy().create(
        repository: widget.repository,
        document: _document,
        pages: pages,
      );
      if (!mounted) return;
      await PageCopy.saveNewFile(
        path: target.path,
        bytes: bytes,
        libraryRoot: widget.repository.root,
      );
      _message('copyPagesDone');
    } catch (_) {
      _message('copyPagesError');
    } finally {
      if (mounted) setState(() => _copyingPages = false);
    }
  }

  Future<void> _export() => _safely(() async {
    final text = AnnotationBundle(
      documentId: _document.id,
      notes: _document.notes,
      bookmarks: _document.bookmarks,
    ).encode();
    if (Platform.isAndroid || Platform.isIOS) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s['export']),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s['annotationsDetail']),
                const SizedBox(height: 12),
                SelectableText(text, textDirection: TextDirection.ltr),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s['close']),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                _message('copied');
              },
              child: Text(s['copy']),
            ),
          ],
        ),
      );
      return;
    }
    final target = await fs.getSaveLocation(
      suggestedName: '${_document.title}.paper.json',
    );
    if (target == null) return;
    // Never allow annotation export to replace any PDF, including an original.
    if (!target.path.toLowerCase().endsWith('.json')) {
      throw const LibraryFormatException('Choose a .json file.');
    }
    if (p.isWithin(
      p.absolute(widget.repository.root.path),
      p.absolute(target.path),
    )) {
      throw const LibraryFormatException(
        'Choose a location outside the app data folder.',
      );
    }
    final file = fs.XFile.fromData(
      utf8.encode(text),
      mimeType: 'application/json',
      name: 'annotations.json',
    );
    await file.saveTo(target.path);
    _message('exportComplete');
  });
  Future<void> _importNotes() => _safely(() async {
    final file = await fs.openFile(
      acceptedTypeGroups: const [
        fs.XTypeGroup(
          label: 'JSON',
          extensions: ['json'],
          mimeTypes: ['application/json'],
          uniformTypeIdentifiers: ['public.json'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 5 * 1024 * 1024) {
      throw const LibraryFormatException('Too large.');
    }
    final bundle = AnnotationBundle.decode(await file.readAsString());
    final state = await widget.repository.mergeAnnotations(
      _document.id,
      bundle,
      pageCount: _pageCount,
    );
    if (mounted) setState(() => _document = state.find(_document.id)!);
    if (mounted) _panelChanges.value++;
    _controller.invalidate();
    _message('importComplete');
  }, error: 'annotationsError');

  void _openPanel(int tab) {
    _tab = tab;
    if (MediaQuery.sizeOf(context).width >= 1000) {
      _setPanelVisible(true);
    } else {
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => ReaderPanelSheet(child: _panel()),
        ),
      );
    }
  }

  Widget _empty(String key) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(s[key], textAlign: TextAlign.center),
    ),
  );
  Iterable<({PdfOutlineNode node, int depth})> _flatten(
    List<PdfOutlineNode> nodes, [
    int depth = 0,
  ]) sync* {
    if (depth > 30) return;
    for (final node in nodes) {
      yield (node: node, depth: depth);
      yield* _flatten(node.children, depth + 1);
    }
  }

  Widget _panel() => ListenableBuilder(
    listenable: _panelChanges,
    builder: (_, _) => DefaultTabController(
      key: ValueKey(_tab),
      length: 4,
      initialIndex: _tab,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: const Icon(Icons.search), text: s['search']),
              Tab(
                icon: const Icon(Icons.format_list_bulleted),
                text: s['outline'],
              ),
              Tab(
                icon: const Icon(Icons.bookmark_outline),
                text: s['bookmarks'],
              ),
              Tab(
                icon: const Icon(Icons.sticky_note_2_outlined),
                text: s['notes'],
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _searchPanel(),
                _outline.isEmpty
                    ? _empty('noOutline')
                    : ListView(
                        children: [
                          for (final item in _flatten(_outline))
                            Padding(
                              padding: EdgeInsetsDirectional.only(
                                start: min(item.depth * 16.0, 120),
                              ),
                              child: ListTile(
                                title: Text(item.node.title),
                                onTap: item.node.dest == null
                                    ? null
                                    : () =>
                                          _controller.goToDest(item.node.dest),
                              ),
                            ),
                        ],
                      ),
                _document.bookmarks.isEmpty
                    ? _empty('noBookmarks')
                    : ListView(
                        children: [
                          for (final page in _document.bookmarks)
                            ListTile(
                              leading: const Icon(Icons.bookmark),
                              title: Text('${s['page']} $page'),
                              onTap: () =>
                                  _controller.goToPage(pageNumber: page),
                              trailing: IconButton(
                                tooltip: s['unbookmark'],
                                icon: const Icon(Icons.close),
                                onPressed: () => _safely(
                                  () => _update(
                                    (d) => d.copyWith(
                                      bookmarks: d.bookmarks
                                          .where((p) => p != page)
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        s['annotationsDetail'],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (_removedNote != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(child: Text(s['readerNoteRemoved'])),
                            TextButton(
                              onPressed: _undoingNote ? null : _undoNoteRemoval,
                              child: Text(s['readerUndo']),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _document.notes.isEmpty
                          ? _empty('noNotes')
                          : ListView(
                              children: [
                                for (final note in _document.notes)
                                  ListTile(
                                    isThreeLine: true,
                                    leading: Icon(
                                      note.boxes.isEmpty
                                          ? Icons.sticky_note_2_outlined
                                          : Icons.highlight,
                                    ),
                                    title: Text('${s['page']} ${note.page}'),
                                    subtitle: Text(
                                      note.text,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _controller.goToPage(
                                      pageNumber: note.page,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: s['readerEditNote'],
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _editNote(note),
                                        ),
                                        IconButton(
                                          tooltip: s['delete'],
                                          icon: const Icon(Icons.close),
                                          onPressed: () => _removeNote(note),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _searchPanel() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _searchField,
          decoration: InputDecoration(
            labelText: s['searchHint'],
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) {
            if (v.trim().isEmpty) {
              _searcher?.resetTextSearch();
            } else {
              _searcher?.startTextSearch(v, goToFirstMatch: true);
            }
          },
        ),
      ),
      if (_searcher?.isSearching ?? false)
        LinearProgressIndicator(value: _searcher?.searchProgress),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: s['previous'],
            onPressed: (_searcher?.hasMatches ?? false)
                ? () => _searcher?.goToPrevMatch()
                : null,
            icon: const Icon(Icons.arrow_upward),
          ),
          Text(
            '${(_searcher?.currentIndex ?? -1) + 1} / ${_searcher?.matches.length ?? 0}',
          ),
          IconButton(
            tooltip: s['next'],
            onPressed: (_searcher?.hasMatches ?? false)
                ? () => _searcher?.goToNextMatch()
                : null,
            icon: const Icon(Icons.arrow_downward),
          ),
        ],
      ),
      Expanded(
        child: (_searcher?.matches.isEmpty ?? true)
            ? _empty(_searchField.text.isEmpty ? 'noSearch' : 'noResults')
            : ListView.builder(
                itemCount: _searcher!.matches.length,
                itemBuilder: (context, index) {
                  final match = _searcher!.matches[index];
                  return ListTile(
                    title: Text('${s['page']} ${match.pageNumber}'),
                    subtitle: Text(
                      match.contextText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: index == _searcher!.currentIndex,
                    onTap: () => _searcher!.goToMatchOfIndex(index),
                  );
                },
              ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final ready = _pageCount > 0;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final book = _document.bookmarks.contains(_page);
    final navigation = PageNavigation(
      page: _page,
      pageCount: _pageCount,
      strings: s,
      onPrevious: ready
          ? () => _controller.goToPage(pageNumber: _page - 1)
          : null,
      onNext: ready ? () => _controller.goToPage(pageNumber: _page + 1) : null,
      onChoose: ready ? _goTo : null,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _closeReader();
      },
      child: ReaderFocusFrame(
        focused: _focusMode,
        onRestore: () => setState(() => _focusMode = false),
        restoreLabel: s['readerShowControls'],
        child: Scaffold(
          appBar: _focusMode
              ? null
              : AppBar(
                  title: Text(
                    _document.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    IconButton(
                      tooltip: s['search'],
                      onPressed: ready ? () => _openPanel(0) : null,
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      tooltip: book ? s['unbookmark'] : s['bookmark'],
                      onPressed: ready ? _bookmark : null,
                      icon: Icon(
                        book ? Icons.bookmark : Icons.bookmark_outline,
                      ),
                    ),
                    for (final tool
                        in _tools
                            .where((tool) => (_pinnedTools & tool.bit) != 0)
                            .take(wide ? 3 : 1))
                      IconButton(
                        tooltip: s[tool.label],
                        onPressed: _toolEnabled(tool)
                            ? () => _selectTool(tool.id)
                            : null,
                        icon: Icon(tool.icon),
                      ),
                    PopupMenuButton<String>(
                      tooltip: s['tools'],
                      enabled: ready,
                      onSelected: _selectTool,
                      itemBuilder: (_) => [
                        PopupMenuItem<String>(
                          enabled: false,
                          child: Text(s['readingTools']),
                        ),
                        for (final tool in _tools.where(
                          (tool) => tool.bit < 16,
                        ))
                          PopupMenuItem(
                            value: tool.id,
                            enabled: _toolEnabled(tool),
                            child: _toolLabel(tool.icon, tool.label),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem<String>(
                          enabled: false,
                          child: Text(s['fileTools']),
                        ),
                        for (final tool in _tools.where(
                          (tool) => tool.bit >= 16,
                        ))
                          PopupMenuItem(
                            value: tool.id,
                            enabled: _toolEnabled(tool),
                            child: _toolLabel(tool.icon, tool.label),
                          ),
                        if (Platform.isMacOS || Platform.isLinux)
                          PopupMenuItem(
                            value: 'copyPages',
                            enabled: ready && !_copyingPages && !_encrypted,
                            child: _toolLabel(
                              Icons.copy_all_outlined,
                              'copyPages',
                            ),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'focus',
                          child: _toolLabel(
                            Icons.fullscreen,
                            'readerFocusMode',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'customize',
                          enabled: _pinsReady && !_customizing,
                          child: _toolLabel(
                            Icons.push_pin_outlined,
                            'toolbarCustomize',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'info',
                          child: _toolLabel(Icons.info_outline, 'limitations'),
                        ),
                      ],
                    ),
                  ],
                ),
          body: Column(
            children: [
              if (_focusMode &&
                  (_saving || _sharing || _printing || _copyingPages))
                LinearProgressIndicator(semanticsLabel: s['saving']),
              Expanded(
                child: Row(
                  children: [
                    if (wide && _panelVisible && !_focusMode)
                      SizedBox(width: 360, child: _panel()),
                    if (wide && _panelVisible && !_focusMode)
                      const VerticalDivider(width: 1),
                    Expanded(
                      child: PdfViewer.file(
                        widget.repository.documentFile(_document.id).path,
                        key: ValueKey('${_document.id}-$_reload'),
                        controller: _controller,
                        initialPageNumber: _document.lastPage,
                        passwordProvider: _password,
                        params: PdfViewerParams(
                          onViewerReady: _ready,
                          onPageChanged: _pageChanged,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          linkHandlerParams: PdfLinkHandlerParams(
                            onLinkTap: (link) => unawaited(_link(link)),
                          ),
                          textSelectionParams: PdfTextSelectionParams(
                            onTextSelectionChange: (selection) async {
                              final version = ++_selectionVersion;
                              final ranges = await selection
                                  .getSelectedTextRanges();
                              if (mounted && version == _selectionVersion) {
                                _selection = ranges;
                              }
                            },
                          ),
                          pagePaintCallbacks: [
                            if (_searcher != null)
                              _searcher!.pageTextMatchPaintCallback,
                            _paintNotes,
                          ],
                          errorBannerBuilder: (context, error, stack, ref) =>
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        s['loadFailed'],
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton(
                                        onPressed: () => setState(() {
                                          _pageCount = 0;
                                          _reload++;
                                        }),
                                        child: Text(s['retry']),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_focusMode)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!wide) navigation,
                        Row(
                          children: [
                            IconButton(
                              tooltip: wide
                                  ? s[_panelVisible
                                        ? 'readerHidePanel'
                                        : 'readerShowPanel']
                                  : s['notes'],
                              onPressed: ready
                                  ? () {
                                      if (wide) {
                                        _setPanelVisible(!_panelVisible);
                                      } else {
                                        _openPanel(3);
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.view_sidebar_outlined),
                            ),
                            if (wide)
                              Expanded(child: navigation)
                            else
                              const Spacer(),
                            IconButton(
                              tooltip: s['zoomOut'],
                              onPressed: ready
                                  ? () => _controller.zoomDown()
                                  : null,
                              icon: const Icon(Icons.zoom_out),
                            ),
                            IconButton(
                              tooltip: s['zoomIn'],
                              onPressed: ready
                                  ? () => _controller.zoomUp()
                                  : null,
                              icon: const Icon(Icons.zoom_in),
                            ),
                            IconButton(
                              tooltip: s['fit'],
                              onPressed: ready
                                  ? () => _controller.goToPage(
                                      pageNumber: _page,
                                      anchor: PdfPageAnchor.all,
                                    )
                                  : null,
                              icon: const Icon(Icons.fit_screen),
                            ),
                            if (wide)
                              Text(
                                _saving ? s['saving'] : s['saved'],
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _noteId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';

class _ReaderTool {
  const _ReaderTool(this.id, this.label, this.icon, this.bit);
  final String id, label;
  final IconData icon;
  final int bit;
}
