import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/ui/selection_actions.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  for (final invalidation in [
    'changed',
    'cleared',
    'reloaded',
    'disposed',
    'permission revoked',
  ]) {
    test('delayed selection $invalidation cannot apply', () async {
      final session = SelectionActionSession();
      final lookup = Completer<String>();
      var mounted = true, permitted = true, hasSelection = true;
      var version = 1, reload = 1, applied = 0;
      final pending = session.run(
        read: () => lookup.future,
        isCurrent: () =>
            mounted && permitted && hasSelection && version == 1 && reload == 1,
        apply: (_) async {
          applied++;
        },
      );
      switch (invalidation) {
        case 'changed':
          version++;
        case 'cleared':
          hasSelection = false;
        case 'reloaded':
          reload++;
        case 'disposed':
          mounted = false;
        case 'permission revoked':
          permitted = false;
      }
      lookup.complete('stale text');
      await pending;
      expect(applied, 0);
    });
  }
  test('repeated lookup applies once and recovers after errors', () async {
    final session = SelectionActionSession();
    final lookup = Completer<String>();
    var reads = 0, applied = 0;
    Future<void> start() => session.run(
      read: () {
        reads++;
        return lookup.future;
      },
      isCurrent: () => true,
      apply: (_) async {
        applied++;
      },
    );
    final first = start();
    await start();
    expect(reads, 1);
    lookup.complete('text');
    await first;
    expect(applied, 1);
    await expectLater(
      session.run<String>(
        read: () async => throw StateError('lookup failed'),
        isCurrent: () => true,
        apply: (_) async {
          applied++;
        },
      ),
      throwsStateError,
    );
    await session.run(
      read: () async => 'fresh',
      isCurrent: () => true,
      apply: (_) async {
        applied++;
      },
    );
    expect(applied, 2);
  });
  for (final language in ['en', 'ar']) {
    test(
      '$language selection actions preserve viewer menu and permissions',
      () {
        final s = PaperStrings(language);
        var highlights = 0, notes = 0;
        final copy = ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed: () {},
        );
        final selectAll = ContextMenuButtonItem(
          type: ContextMenuButtonType.selectAll,
          onPressed: () {},
        );
        final items = [copy, selectAll];
        void append(bool enabled) => appendSelectionActions(
          items,
          enabled: enabled,
          highlightLabel: s['selectionLocalHighlight'],
          noteLabel: s['selectionLocalNote'],
          onHighlight: () => highlights++,
          onNote: () => notes++,
        );
        append(false);
        expect(items, [copy, selectAll]);
        append(true);
        expect(items.length, 4);
        expect(identical(items[1], selectAll), isTrue);
        expect(identical(items.first, copy), isTrue);
        expect(items[2].label, s['selectionLocalHighlight']);
        expect(items[3].label, s['selectionLocalNote']);
        items[2].onPressed!();
        items[3].onPressed!();
        expect(highlights, 1);
        expect(notes, 1);
      },
    );
  }
}
