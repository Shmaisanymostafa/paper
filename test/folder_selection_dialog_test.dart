import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/services/folder_discovery.dart';
import 'package:cave_paper/ui/folder_selection_dialog.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  test('candidate enumeration is bounded and duplicate paths are refused', () {
    var yielded = 0;
    Iterable<FolderPdfCandidate> endless() sync* {
      while (true) {
        yielded++;
        yield FolderPdfCandidate('/$yielded.pdf', 1);
      }
    }

    expect(
      () => FolderSelectionDialog(
        candidates: endless(),
        strings: const PaperStrings('en'),
        incomplete: false,
      ),
      throwsArgumentError,
    );
    expect(yielded, 5001);
    expect(
      () => FolderSelectionDialog(
        candidates: const [
          FolderPdfCandidate('/same.pdf', 1),
          FolderPdfCandidate('/same.pdf', 2),
        ],
        strings: const PaperStrings('en'),
        incomplete: false,
      ),
      throwsArgumentError,
    );
  });

  for (final language in ['en', 'ar']) {
    testWidgets('$language explicit bounded selection and cancel at 2x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = PaperStrings(language);
      List<FolderPdfCandidate>? result;
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await showDialog<List<FolderPdfCandidate>>(
                    context: context,
                    builder: (_) => FolderSelectionDialog(
                      candidates: const [
                        FolderPdfCandidate('/chosen/one.pdf', 10),
                        FolderPdfCandidate('/chosen/two.pdf', 10),
                      ],
                      strings: s,
                      incomplete: true,
                      maxSelection: 1,
                    ),
                  );
                  completed++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text(s['cancel']));
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(result, isNull);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('/chosen/one.pdf'));
      await tester.scrollUntilVisible(first, 150);
      await tester.pumpAndSettle();
      await tester.tap(first);
      await tester.pumpAndSettle();
      final second = find.byKey(const ValueKey('/chosen/two.pdf'));
      await tester.scrollUntilVisible(second, 100);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(second).onChanged, isNull);
      await tester.tap(find.text(s['folderSelectConfirm']));
      await tester.pumpAndSettle();
      expect(completed, 2);
      expect(result!.single.path, '/chosen/one.pdf');
      expect(() => result!.clear(), throwsUnsupportedError);
      expect(tester.takeException(), isNull);
    });
  }
}
