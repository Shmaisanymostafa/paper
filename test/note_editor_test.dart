import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/ui/note_editor_dialog.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('$language note editor cancel/save/empty validation', (
      tester,
    ) async {
      final s = PaperStrings(language);
      String? result = 'unanswered';
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
                    builder: (_) => NoteEditorDialog(
                      title: 'Edit',
                      strings: s,
                      initialText: 'Original',
                    ),
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
      await tester.enterText(find.byType(TextField), 'Changed');
      await tester.tap(find.text(s['cancel']));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Original',
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), ' Edited ');
      await tester.pump();
      await tester.tap(find.text(s['save']));
      await tester.pumpAndSettle();
      expect(result, 'Edited');
      expect(tester.takeException(), isNull);
    });
  }
}
