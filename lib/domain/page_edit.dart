// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'library.dart';

/// One page of an edited PDF: which library document and page it comes from,
/// and how many clockwise quarter turns to add to its own rotation.
class EditedPage {
  const EditedPage(this.documentId, this.page, {this.turns = 0, this.key = 0});
  final String documentId;
  final int page;
  final int turns;

  /// Stable identity for lists while pages move; not written to the PDF.
  final int key;

  EditedPage rotated(int quarterTurns) =>
      EditedPage(documentId, page, turns: (turns + quarterTurns) % 4, key: key);
}

/// An immutable plan for a new PDF assembled from library pages. Editing never
/// touches the originals: the result is saved as a new library document.
/// Every change returns a new plan, so undo is keeping the previous one.
class PageEditPlan {
  PageEditPlan._(List<EditedPage> pages, this._nextKey)
    : pages = List.unmodifiable(pages);

  /// All pages of [document] in order, as found in the PDF.
  factory PageEditPlan.of(String documentId, int pageCount) {
    _checkCount(pageCount);
    return PageEditPlan._([
      for (var i = 0; i < pageCount; i++) EditedPage(documentId, i + 1, key: i),
    ], pageCount);
  }

  static const maxPages = 2000;
  final List<EditedPage> pages;
  final int _nextKey;

  int get length => pages.length;
  bool get isEmpty => pages.isEmpty;
  Set<String> get documentIds => {for (final p in pages) p.documentId};

  /// True when the plan is the untouched original of a single document.
  bool isOriginal(String documentId, int pageCount) =>
      pages.length == pageCount &&
      [
        for (var i = 0; i < pages.length; i++)
          pages[i].documentId == documentId &&
              pages[i].page == i + 1 &&
              pages[i].turns == 0,
      ].every((same) => same);

  PageEditPlan rotate(Set<int> keys, int quarterTurns) => PageEditPlan._([
    for (final p in pages) keys.contains(p.key) ? p.rotated(quarterTurns) : p,
  ], _nextKey);

  PageEditPlan remove(Set<int> keys) => PageEditPlan._([
    for (final p in pages)
      if (!keys.contains(p.key)) p,
  ], _nextKey);

  /// Only the pages in [keys], in their current order (split / extract).
  PageEditPlan keepOnly(Set<int> keys) => PageEditPlan._([
    for (final p in pages)
      if (keys.contains(p.key)) p,
  ], _nextKey);

  /// Moves the page at [from] so it ends up at [to] (indexes after removal,
  /// matching [ReorderableListView] once its index is adjusted).
  PageEditPlan move(int from, int to) {
    if (from < 0 || from >= pages.length || to < 0 || to >= pages.length) {
      throw const LibraryFormatException('Invalid page move.');
    }
    final next = [...pages];
    final page = next.removeAt(from);
    next.insert(to, page);
    return PageEditPlan._(next, _nextKey);
  }

  /// Appends every page of another document (merge).
  PageEditPlan append(String documentId, int pageCount) {
    _checkCount(pageCount);
    if (pages.length + pageCount > maxPages) {
      throw const LibraryFormatException('Too many pages.');
    }
    return PageEditPlan._([
      ...pages,
      for (var i = 0; i < pageCount; i++)
        EditedPage(documentId, i + 1, key: _nextKey + i),
    ], _nextKey + pageCount);
  }

  /// Puts the same pages in the reverse order.
  PageEditPlan reversed() => PageEditPlan._(pages.reversed.toList(), _nextKey);

  static void _checkCount(int pageCount) {
    if (pageCount < 1 || pageCount > maxPages) {
      throw const LibraryFormatException('Invalid page count.');
    }
  }
}

/// Title for the new document, e.g. "Report.pdf" → "Report (edited).pdf".
String editedTitle(String title, String suffix) {
  final lower = title.toLowerCase();
  final base = lower.endsWith('.pdf')
      ? title.substring(0, title.length - 4)
      : title;
  final trimmed = base.length > 200 ? base.substring(0, 200) : base;
  return '$trimmed ($suffix).pdf';
}
