// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'library.dart';

/// Conflict-aware sidecar edits. Never changes PDF bytes or a newer note.
class NoteChanges {
  static int _index(PaperDocument document, PaperNote expected) {
    final index = document.notes.indexWhere((note) => note.id == expected.id);
    if (index < 0 ||
        jsonEncode(document.notes[index].toJson()) !=
            jsonEncode(expected.toJson())) {
      throw const LibraryFormatException(
        'The note changed. Reopen it and try again.',
      );
    }
    return index;
  }

  static PaperDocument edit(
    PaperDocument document,
    PaperNote expected,
    String text,
  ) {
    final index = _index(document, expected);
    final notes = [...document.notes];
    notes[index] = PaperNote(
      id: expected.id,
      page: expected.page,
      text: text,
      createdAt: expected.createdAt,
      boxes: expected.boxes,
    );
    return document.copyWith(notes: notes);
  }

  static PaperDocument remove(PaperDocument document, PaperNote expected) {
    final notes = [...document.notes]..removeAt(_index(document, expected));
    return document.copyWith(notes: notes);
  }

  static PaperDocument restore(
    PaperDocument document,
    PaperNote removed,
    int index,
  ) {
    if (document.notes.any((note) => note.id == removed.id)) {
      throw const LibraryFormatException('A note with this ID already exists.');
    }
    final notes = [...document.notes];
    notes.insert(index.clamp(0, notes.length), removed);
    return document.copyWith(notes: notes);
  }
}
