import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cave_paper/ui/page_copy_dialog.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  for (final language in ['en', 'ar']) {
    for (final compact in [false, true]) {
      testWidgets(
        '$language compact=$compact copy warning requires consent and cancel returns no selection',
        (tester) async {
          await tester.binding.setSurfaceSize(
            compact ? const Size(360, 640) : const Size(390, 844),
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final s = PaperStrings(language);
          PageCopyRequest? result;
          var completions = 0;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(compact ? 2 : 1)),
                child: child!,
              ),
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showDialog<PageCopyRequest>(
                        context: context,
                        builder: (_) =>
                            PageCopyDialog(page: 2, pageCount: 3, strings: s),
                      );
                      completions++;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.text(s['copyPagesWarning']), findsOneWidget);
          final choose = find.widgetWithText(FilledButton, s['saveCopy']);
          expect(tester.widget<FilledButton>(choose).onPressed, isNull);
          await Scrollable.ensureVisible(
            tester.element(find.byType(Checkbox)),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(Checkbox));
          await tester.pump();
          expect(tester.widget<FilledButton>(choose).onPressed, isNotNull);
          await tester.enterText(find.byType(TextField), '999');
          await tester.tap(choose);
          await tester.pumpAndSettle();
          expect(find.text(s['copyPageSelectionError']), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            '999',
          );
          await tester.tap(find.text(s['cancel']));
          await tester.pumpAndSettle();
          expect(result, isNull);
          expect(completions, 1);
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '3,1,3');
          await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          await tester.tap(find.text(s['pageRotation1']).last);
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(
            tester.element(find.byType(Checkbox)),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(Checkbox));
          await tester.pump();
          await tester.tap(find.widgetWithText(FilledButton, s['saveCopy']));
          await tester.pumpAndSettle();
          expect(completions, 2);
          expect(result!.pages, [3, 1, 3]);
          expect(result!.clockwiseQuarterTurns, 1);
          expect(() => result!.pages.add(2), throwsUnsupportedError);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
