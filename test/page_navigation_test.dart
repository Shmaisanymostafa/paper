import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cave_paper/ui/page_navigation.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('$language arrows boundaries, actions and compact large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final s = PaperStrings(language);
      var previous = 0, next = 0, choose = 0;
      Finder button(String label) =>
          find.byWidgetPredicate((w) => w is IconButton && w.tooltip == label);
      Future<void> show(int page, int count) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: PageNavigation(
                  page: page,
                  pageCount: count,
                  strings: s,
                  onPrevious: () => previous++,
                  onNext: () => next++,
                  onChoose: () => choose++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await show(1, 3);
      expect(
        tester.widget<IconButton>(button(s['previousPage'])).onPressed,
        isNull,
      );
      await tester.tap(button(s['nextPage']));
      expect(next, 1);
      await show(2, 3);
      await tester.tap(button(s['previousPage']));
      await tester.tap(find.byType(TextButton));
      expect(previous, 1);
      expect(choose, 1);
      final prevX = tester.getCenter(button(s['previousPage'])).dx;
      final nextX = tester.getCenter(button(s['nextPage'])).dx;
      expect(language == 'ar' ? prevX > nextX : prevX < nextX, isTrue);
      expect(Icons.arrow_back.matchTextDirection, isTrue);
      expect(Icons.arrow_forward.matchTextDirection, isTrue);
      await show(3, 3);
      expect(
        tester.widget<IconButton>(button(s['nextPage'])).onPressed,
        isNull,
      );
      await show(0, 0);
      expect(
        tester.widget<IconButton>(button(s['previousPage'])).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(button(s['nextPage'])).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
    });
  }
}
