import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/services/default_pdf_app.dart';
import 'package:cave_paper/ui/default_app_status.dart';
import 'package:cave_paper/ui/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  Object? handler;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(DefaultPdfApp.channel, (call) async {
      calls.add(call);
      return call.method == 'pdfHandler' ? handler : true;
    });
  });
  tearDown(
    () => messenger.setMockMethodCallHandler(DefaultPdfApp.channel, null),
  );

  Future<void> pump(WidgetTester tester, String language) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAppStatus(
            app: DefaultPdfApp(platform: 'android'),
            strings: PaperStrings(language),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names the app that opens PDFs and opens only its settings', (
    tester,
  ) async {
    handler = {
      'package': 'com.adobe.reader',
      'label': 'Adobe Acrobat',
      'self': false,
    };
    await pump(tester, 'en');
    expect(find.text('Adobe Acrobat opens your PDFs right now.'), findsOne);
    await tester.tap(find.text('Open Adobe Acrobat settings'));
    await tester.pump();
    expect(calls.last.method, 'openAppSettings');
    expect(calls.last.arguments, 'com.adobe.reader');
  });

  testWidgets('says when Cave Paper is already the PDF app', (tester) async {
    handler = {
      'package': 'technology.cave.paper',
      'label': 'Cave Paper',
      'self': true,
    };
    await pump(tester, 'ar');
    expect(find.byKey(const Key('default-app-self')), findsOne);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('no default, or an unclear answer, shows the choose steps', (
    tester,
  ) async {
    for (final answer in [
      null,
      {'package': '', 'label': 'x'},
      {'label': 'x'},
    ]) {
      handler = answer;
      await pump(tester, 'en');
      expect(find.byKey(const Key('default-app-none')), findsOne);
    }
  });

  test('other platforms never ask Android', () async {
    for (final platform in ['ios', 'macos', 'windows', 'linux']) {
      final app = DefaultPdfApp(platform: platform);
      expect(await app.currentHandler(), isNull);
      expect(
        await app.openHandlerSettings((
          package: 'a.b',
          label: 'A',
          isSelf: false,
        )),
        isFalse,
      );
    }
    expect(calls, isEmpty);
  });
}
