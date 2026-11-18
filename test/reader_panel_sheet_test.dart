import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/ui/reader_panel_sheet.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets('$direction $size mobile tools stay above keyboard', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: Directionality(textDirection: direction, child: child!),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Search'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ReaderPanelSheet(
                      child: Column(
                        children: [
                          const SizedBox(
                            height: 72,
                            child: Text(
                              'Search / Contents / Bookmarks / Notes',
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: TextField(key: ValueKey('query')),
                          ),
                          const SizedBox(
                            height: 48,
                            child: Text('Previous / Next'),
                          ),
                          Expanded(
                            child: ListView(
                              children: const [Text('Search result')],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Search'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('query')), 'word');
        for (final keyboard in [250.0, 0.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final bottom = tester
              .getBottomLeft(
                find.descendant(
                  of: find.byType(ReaderPanelSheet),
                  matching: find.byType(SafeArea),
                ),
              )
              .dy;
          expect(bottom, lessThanOrEqualTo(size.height - keyboard));
          expect(find.text('word'), findsOneWidget);
          expect(find.text('Search result'), findsOneWidget);
        }
        final context = tester.element(find.byType(ReaderPanelSheet));
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        expect(find.byType(ReaderPanelSheet), findsNothing);
      });
    }
  }
}
