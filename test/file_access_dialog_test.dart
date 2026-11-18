import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/ui/file_access_dialog.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language file access explanation cancels or proceeds explicitly',
      (tester) async {
        final s = PaperStrings(language);
        bool? result;
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
                    result = await showDialog<bool>(
                      context: context,
                      builder: (_) => FileAccessDialog(strings: s),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(s['cancel']));
        await tester.pumpAndSettle();
        expect(result, false);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(s['fileAccessChoose']));
        await tester.pumpAndSettle();
        expect(result, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
