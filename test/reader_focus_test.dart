import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cave_paper/ui/reader_focus_frame.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:cave_paper/data/library_repository.dart';

void main() {
  test(
    'panel preference is backward compatible and survives unrelated settings',
    () async {
      expect(
        PaperSettings.fromJson({'appearance': 'system', 'language': 'en'})
            .readerPanelVisible,
        isTrue,
      );
      expect(
        () => PaperSettings.fromJson({
          'appearance': 'system',
          'language': 'en',
          'readerPanelVisible': 'false',
        }),
        throwsA(isA<LibraryFormatException>()),
      );
      final dir = await Directory.systemTemp.createTemp('paper-panel-');
      try {
        final repo = LibraryRepository(dir);
        await repo.setReaderPanelVisible(false);
        await repo.setPinnedTools(3);
        await repo.setDisplaySettings(
          const PaperSettings(language: 'ar', appearance: Appearance.dark),
        );
        final state = await LibraryRepository(dir).load();
        expect(state.settings.readerPanelVisible, isFalse);
        expect(state.settings.pinnedTools, 3);
        expect(state.settings.language, 'ar');
        await repo.setReaderPanelVisible(true);
        expect((await repo.load()).settings.readerPanelVisible, isTrue);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
  for (final rtl in [false, true]) {
    testWidgets('focus mode restores by button and Escape rtl=$rtl', (
      tester,
    ) async {
      var focused = true;
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: ReaderFocusFrame(
                  focused: focused,
                  restoreLabel: 'Show controls',
                  onRestore: () => setState(() => focused = false),
                  child: const Scaffold(body: Text('PDF remains')),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Show controls',
      );
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(focused, isFalse);
      expect(button, findsNothing);
      expect(find.text('PDF remains'), findsOneWidget);
      refresh(() => focused = true);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(focused, isFalse);
      expect(find.text('PDF remains'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('focus retains child input/scroll and modal Escape stays modal', (
    tester,
  ) async {
    var focused = false;
    late StateSetter refresh;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return ReaderFocusFrame(
              focused: focused,
              restoreLabel: 'Restore',
              onRestore: () => setState(() => focused = false),
              child: Scaffold(
                body: Column(
                  children: [
                    const TextField(key: ValueKey('kept-input')),
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const AlertDialog(title: Text('Modal')),
                      ),
                      child: const Text('Modal open'),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scroll,
                        children: List.generate(
                          40,
                          (i) => SizedBox(height: 60, child: Text('Row $i')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Preserve this');
    scroll.jumpTo(400);
    await tester.pump();
    refresh(() => focused = true);
    await tester.pumpAndSettle();
    expect(find.text('Preserve this'), findsOneWidget);
    expect(scroll.offset, 400);
    await tester.tap(find.text('Modal open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Modal'), findsNothing);
    expect(focused, isTrue);
    refresh(() => focused = false);
    await tester.pumpAndSettle();
    expect(find.text('Preserve this'), findsOneWidget);
    expect(scroll.offset, 400);
    expect(tester.takeException(), isNull);
  });
}
