import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/domain/note_changes.dart';
import 'package:cave_paper/data/library_repository.dart';

void main() {
  test(
    'edit/delete/undo preserves geometry, unrelated notes and PDF bytes',
    () async {
      final dir = await Directory.systemTemp.createTemp('paper-note-edit-');
      try {
        final repo = LibraryRepository(dir);
        final bytes = await File('assets/sample.pdf').readAsBytes();
        final doc = await repo.importPdf(
          name: 'sample.pdf',
          bytes: Stream.value(bytes),
        );
        final note = PaperNote(
          id: 'note1',
          page: 2,
          text: 'Original',
          createdAt: DateTime.utc(2026),
          boxes: [HighlightBox(1, 10, 9, 1)],
        );
        final other = PaperNote(
          id: 'note2',
          page: 1,
          text: 'Other',
          createdAt: DateTime.utc(2026),
        );
        await repo.updateDocument(
          doc.id,
          (d) => d.copyWith(notes: [note, other]),
        );
        var state = await repo.updateDocument(
          doc.id,
          (d) => NoteChanges.edit(d, note, 'Edited'),
        );
        final edited = state.find(doc.id)!.notes.first;
        expect(edited.text, 'Edited');
        expect(
          NoteChanges.edit(state.find(doc.id)!, edited, '').notes.first.text,
          isEmpty,
        );
        expect(
          () => NoteChanges.edit(state.find(doc.id)!, other, ''),
          throwsA(isA<LibraryFormatException>()),
        );
        expect(edited.boxes.single.toJson(), note.boxes.single.toJson());
        expect(edited.createdAt, note.createdAt);
        expect(edited.page, note.page);
        await expectLater(
          repo.updateDocument(
            doc.id,
            (d) => NoteChanges.edit(d, note, 'Stale'),
          ),
          throwsA(isA<LibraryFormatException>()),
        );
        await repo.updateDocument(doc.id, (d) => NoteChanges.remove(d, edited));
        state = await repo.updateDocument(
          doc.id,
          (d) => NoteChanges.restore(d, edited, 0),
        );
        expect(state.find(doc.id)!.notes.map((n) => n.id), ['note1', 'note2']);
        await expectLater(
          repo.updateDocument(doc.id, (d) => NoteChanges.restore(d, edited, 0)),
          throwsA(isA<LibraryFormatException>()),
        );
        expect(
          (await LibraryRepository(dir).load()).find(doc.id)!.notes.first.text,
          'Edited',
        );
        expect(await repo.documentFile(doc.id).readAsBytes(), bytes);
        await repo.verifyDocument(doc);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
