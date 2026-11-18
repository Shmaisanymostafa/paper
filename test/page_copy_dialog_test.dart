import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cave_paper/ui/page_copy_dialog.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language copy warning requires consent and cancel returns no selection',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final s = PaperStrings(language);
        String? result = 'not-returned';
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                      context: context,
                      builder: (_) =>
                          PageCopyDialog(page: 2, pageCount: 3, strings: s),
                    );
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
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
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
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '3,1,3');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, s['saveCopy']));
        await tester.pumpAndSettle();
        expect(result, '3,1,3');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
