import 'dart:async';

import 'package:flutter/services.dart';
import 'package:cave_paper/ui/reader_panel_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/ui/reader_focus_frame.dart';

void main() {
  test(
    'mobile panel gates same-turn activation and reopens after dismissal',
    () async {
      final session = ReaderPanelSession();
      var calls = 0;
      final dismissed = Completer<void>();
      final first = session.show(() {
        calls++;
        return dismissed.future;
      });
      await session.show(() async {
        calls++;
      });
      expect(calls, 1);
      dismissed.complete();
      await first;
      await session.show(() async {
        calls++;
      });
      expect(calls, 2);
      await expectLater(
        session.show(() async => throw StateError('route failed')),
        throwsStateError,
      );
      await session.show(() async {
        calls++;
      });
      expect(calls, 3);
    },
  );
  for (final modifier in [
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.metaLeft,
  ]) {
    testWidgets('$modifier find is available but cannot cross a modal', (
      tester,
    ) async {
      var finds = 0;
      late BuildContext readerContext;
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderFocusFrame(
            focused: false,
            onRestore: () {},
            restoreLabel: 'Restore',
            onSearch: () => finds++,
            child: Builder(
              builder: (context) {
                readerContext = context;
                return const Scaffold(body: TextField());
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Existing query');
      Future<void> triggerFind() async {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
      }

      await triggerFind();
      expect(finds, 1);
      expect(find.text('Existing query'), findsOneWidget);
      unawaited(
        showDialog<void>(
          context: readerContext,
          builder: (_) => const AlertDialog(content: TextField()),
        ),
      );
      await tester.pumpAndSettle();
      await triggerFind();
      expect(finds, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
