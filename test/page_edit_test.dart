import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/domain/library_listing.dart';
import 'package:cave_paper/domain/page_edit.dart';
import 'package:cave_paper/ui/spread_layout.dart';
import 'package:cave_paper/ui/strings.dart';

final a = 'a' * 64, b = 'b' * 64;

List<(String, int, int)> pages(PageEditPlan plan) => [
  for (final p in plan.pages) (p.documentId == a ? 'a' : 'b', p.page, p.turns),
];

void main() {
  group('PageEditPlan', () {
    test('starts as the original and edits never mutate earlier plans', () {
      final original = PageEditPlan.of(a, 3);
      expect(original.isOriginal(a, 3), isTrue);
      expect(pages(original), [('a', 1, 0), ('a', 2, 0), ('a', 3, 0)]);

      final keys = original.pages.map((p) => p.key).toList();
      final rotated = original.rotate({keys[1]}, 1).rotate({keys[1]}, 1);
      expect(pages(rotated)[1], ('a', 2, 2));
      expect(
        rotated.rotate({keys[1]}, 3).rotate({keys[1]}, 3).pages[1].turns,
        0,
      );
      expect(rotated.isOriginal(a, 3), isFalse);

      final moved = original.move(0, 2);
      expect(pages(moved).map((p) => p.$2), [2, 3, 1]);
      expect(moved.move(2, 0).isOriginal(a, 3), isTrue);

      expect(pages(original.remove({keys[0]})).map((p) => p.$2), [2, 3]);
      expect(pages(original.keepOnly({keys[2], keys[0]})).map((p) => p.$2), [
        1,
        3,
      ]);
      expect(pages(original.reversed()).map((p) => p.$2), [3, 2, 1]);
      // The first plan is untouched by everything above.
      expect(original.isOriginal(a, 3), isTrue);
    });

    test('merging appends pages with keys that never collide', () {
      final merged = PageEditPlan.of(a, 2).append(b, 2);
      expect(pages(merged), [
        ('a', 1, 0),
        ('a', 2, 0),
        ('b', 1, 0),
        ('b', 2, 0),
      ]);
      expect(merged.documentIds, {a, b});
      final keys = merged.pages.map((p) => p.key).toSet();
      expect(keys.length, 4);
      final again = merged.remove({merged.pages.last.key}).append(b, 1);
      expect(again.pages.map((p) => p.key).toSet().length, again.length);
    });

    test('rejects bad counts, moves and oversized merges', () {
      expect(
        () => PageEditPlan.of(a, 0),
        throwsA(isA<LibraryFormatException>()),
      );
      expect(
        () => PageEditPlan.of(a, 2001),
        throwsA(isA<LibraryFormatException>()),
      );
      final plan = PageEditPlan.of(a, 2);
      expect(() => plan.move(0, 2), throwsA(isA<LibraryFormatException>()));
      expect(() => plan.move(-1, 0), throwsA(isA<LibraryFormatException>()));
      expect(
        () => PageEditPlan.of(a, 1500).append(b, 600),
        throwsA(isA<LibraryFormatException>()),
      );
    });

    test('edited titles keep one .pdf and stay within the title limit', () {
      expect(editedTitle('Report.pdf', 'edited'), 'Report (edited).pdf');
      expect(editedTitle('Notes', 'معدّل'), 'Notes (معدّل).pdf');
      expect(editedTitle('${'x' * 239}.PDF', 'edited').length, lessThan(240));
    });
  });

  group('two-page spread', () {
    test('pairs pages left to right and centres a last single page', () {
      final r = spreadRects(const [
        Size(100, 200),
        Size(100, 200),
        Size(100, 150),
      ], margin: 10);
      expect(r.size, const Size(230, 10 + 200 + 10 + 150 + 10));
      expect(r.pages[0], const Rect.fromLTWH(10, 10, 100, 200));
      expect(r.pages[1], const Rect.fromLTWH(120, 10, 100, 200));
      expect(r.pages[2], const Rect.fromLTWH(65, 220, 100, 150));
    });

    test('right-to-left puts the first page of each pair on the right', () {
      final r = spreadRects(
        const [Size(100, 200), Size(100, 100)],
        margin: 10,
        rtl: true,
      );
      expect(r.pages[0].left, 120);
      expect(r.pages[1].left, 10);
      // The shorter page is centred vertically in its row.
      expect(r.pages[1].top, 60);
      expect(spreadRects(const [], margin: 10).pages, isEmpty);
    });
  });

  group('library metadata', () {
    test('favourite and page count round-trip, and old data still loads', () {
      final doc = PaperDocument(
        id: a,
        title: 'A.pdf',
        byteLength: 8,
        importedAt: DateTime.utc(2026),
        lastPage: 5,
        pageCount: 9,
        favorite: true,
      );
      final back = PaperDocument.fromJson(doc.toJson());
      expect(back.favorite, isTrue);
      expect(back.pageCount, 9);
      expect(back.progress, 0.5);
      final old = doc.toJson()
        ..remove('favorite')
        ..remove('pageCount');
      final legacy = PaperDocument.fromJson(old);
      expect(legacy.favorite, isFalse);
      expect(legacy.pageCount, isNull);
      expect(legacy.progress, isNull);
      expect(
        () => PaperDocument.fromJson({...doc.toJson(), 'favorite': 'yes'}),
        throwsA(isA<LibraryFormatException>()),
      );
      expect(
        () => PaperDocument.fromJson({...doc.toJson(), 'pageCount': 0}),
        throwsA(isA<LibraryFormatException>()),
      );
      expect(doc.copyWith(pageCount: 1, lastPage: 1).progress, 1);
    });

    test('reader view settings default off and reject bad values', () {
      const settings = PaperSettings();
      final json = settings.toJson();
      expect(json['nightPages'], isFalse);
      expect(json['twoPages'], isFalse);
      final on = PaperSettings.fromJson({
        ...json,
        'nightPages': true,
        'twoPages': true,
      });
      expect(on.nightPages && on.twoPages, isTrue);
      final legacy = Map<String, dynamic>.of(json)
        ..remove('nightPages')
        ..remove('twoPages');
      expect(PaperSettings.fromJson(legacy).nightPages, isFalse);
      expect(
        () => PaperSettings.fromJson({...json, 'nightPages': 1}),
        throwsA(isA<LibraryFormatException>()),
      );
    });

    test('favourites filter keeps the chosen order', () {
      PaperDocument doc(String id, String title, bool favorite) =>
          PaperDocument(
            id: id * 64,
            title: title,
            byteLength: 8,
            importedAt: DateTime.utc(2026),
            favorite: favorite,
          );
      final docs = [
        doc('a', 'Zulu', true),
        doc('b', 'Beta', false),
        doc('c', 'Alpha', true),
      ];
      expect(
        libraryListing(
          docs,
          query: '',
          sort: LibrarySort.title,
          favoritesOnly: true,
        ).map((d) => d.title),
        ['Alpha', 'Zulu'],
      );
    });
  });

  test('new strings exist in English and Arabic', () {
    for (final key in PaperStrings.en.keys) {
      expect(PaperStrings.ar.containsKey(key), isTrue, reason: key);
    }
    for (final key in [
      'editPages',
      'nightPages',
      'twoPages',
      'pageOf',
      'deviceSortModified',
      'favoritesOnly',
    ]) {
      expect(PaperStrings.en[key], isNotEmpty);
    }
  });
}
