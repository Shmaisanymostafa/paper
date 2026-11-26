import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/domain/note_changes.dart';
import 'package:cave_paper/ui/ink_drawing.dart';
import 'package:cave_paper/ui/strings.dart';

PaperNote drawing({List<InkStroke>? ink, int? color = 0x5BA8F5}) => PaperNote(
  id: 'd1',
  page: 2,
  text: '',
  color: color,
  ink:
      ink ??
      [
        InkStroke([1, 2, 3, 4]),
      ],
  createdAt: DateTime.utc(2026),
);

void main() {
  group('drawings and colours in the library', () {
    test('a drawing round-trips with its strokes and colour', () {
      final note = drawing(
        ink: [
          InkStroke([1, 2, 3, 4, 5, 6]),
          InkStroke([7, 8, 9, 10]),
        ],
      );
      final back = PaperNote.fromJson(
        jsonDecode(jsonEncode(note.toJson())) as Map<String, dynamic>,
      );
      expect(back.ink.map((s) => s.points), [
        [1, 2, 3, 4, 5, 6],
        [7, 8, 9, 10],
      ]);
      expect(back.color, 0x5BA8F5);
      expect(back.isDrawing, isTrue);
      expect(back.displayColor, 0x5BA8F5);
    });

    test('old notes without ink or colour load with default colours', () {
      final old = {
        'id': 'n',
        'page': 1,
        'text': 'x',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'boxes': [
          [1, 10, 10, 1],
        ],
      };
      final note = PaperNote.fromJson(old);
      expect(note.ink, isEmpty);
      expect(note.color, isNull);
      expect(note.displayColor, defaultHighlightColor);
      // Plain notes are written without the new keys.
      expect(note.toJson().containsKey('ink'), isFalse);
      expect(note.toJson().containsKey('color'), isFalse);
      expect(drawing(color: null).displayColor, defaultPenColor);
    });

    test('bad strokes, colours and mixed notes are rejected', () {
      for (final points in [
        <double>[1, 2],
        <double>[1, 2, 3],
        <double>[1, double.nan, 3, 4],
      ]) {
        expect(() => InkStroke(points), throwsA(isA<LibraryFormatException>()));
      }
      expect(
        () => drawing(color: 0x1000000),
        throwsA(isA<LibraryFormatException>()),
      );
      expect(
        () => PaperNote(
          id: 'm',
          page: 1,
          text: '',
          boxes: [HighlightBox(1, 10, 10, 1)],
          ink: [
            InkStroke([1, 2, 3, 4]),
          ],
          createdAt: DateTime.utc(2026),
        ),
        throwsA(isA<LibraryFormatException>()),
      );
      expect(
        () => PaperNote.fromJson({
          ...drawing().toJson(),
          'ink': [
            ['a', 'b'],
          ],
        }),
        throwsA(isA<LibraryFormatException>()),
      );
      expect(
        () => PaperNote.fromJson({...drawing().toJson(), 'color': '#fff'}),
        throwsA(isA<LibraryFormatException>()),
      );
    });

    test('editing a drawing caption keeps its strokes and colour', () {
      final note = drawing();
      final doc = PaperDocument(
        id: 'a' * 64,
        title: 'A.pdf',
        byteLength: 8,
        importedAt: DateTime.utc(2026),
        notes: [note],
      );
      final edited = NoteChanges.edit(
        doc,
        note,
        'Arrow to the total',
      ).notes.single;
      expect(edited.text, 'Arrow to the total');
      expect(edited.ink.single.points, [1, 2, 3, 4]);
      expect(edited.color, 0x5BA8F5);
    });

    test('settings keep the chosen colours and reject bad ones', () {
      final json = const PaperSettings(
        highlightColor: 0x4CC38A,
        penColor: 0xE5484D,
      ).toJson();
      final back = PaperSettings.fromJson(json);
      expect((back.highlightColor, back.penColor), (0x4CC38A, 0xE5484D));
      final legacy = Map<String, dynamic>.of(json)
        ..remove('highlightColor')
        ..remove('penColor');
      expect(PaperSettings.fromJson(legacy).penColor, defaultPenColor);
      expect(
        () => PaperSettings.fromJson({...json, 'penColor': -1}),
        throwsA(isA<LibraryFormatException>()),
      );
    });
  });

  group('stroke smoothing', () {
    test('drops jitter, keeps the end point, caps very long strokes', () {
      final points = [
        const Offset(0, 0),
        const Offset(0.5, 0),
        const Offset(2, 0),
        const Offset(2.2, 0),
      ];
      expect(simplifyStroke(points), [
        const Offset(0, 0),
        const Offset(2, 0),
        const Offset(2.2, 0),
      ]);
      final long = [for (var i = 0; i < 5000; i++) Offset(i * 2.0, 0)];
      final capped = simplifyStroke(long, maxPoints: 100);
      expect(capped.length, 100);
      expect(capped.first, long.first);
      expect(capped.last, long.last);
    });
  });

  test('colour names exist in both languages', () {
    for (final key in [
      'colorYellow',
      'colorInk',
      'draw',
      'drawDone',
      'inThisPdf',
      'highlightColor',
      'defaultAppCurrent',
    ]) {
      expect(PaperStrings.en[key], isNotEmpty, reason: key);
      expect(PaperStrings.ar[key], isNotEmpty, reason: key);
    }
    expect(markColors, contains(defaultHighlightColor));
    expect(markColors, contains(defaultPenColor));
  });
}
