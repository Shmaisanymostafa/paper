import 'package:cave_paper/data/external_documents.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cold-start documents drained and release forwarded', () async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(ExternalDocuments.channel, (call) async {
      calls.add(call);
      return call.method == 'ready' ? ['/tmp/sample.pdf'] : null;
    });
    final adapter = ExternalDocuments();
    final paths = <String>[];
    await adapter.start(paths.add);
    expect(paths, ['/tmp/sample.pdf']);
    await adapter.release(paths.single);
    expect(calls.last.method, 'release');
    expect(calls.last.arguments, paths.single);
    adapter.dispose();
    messenger.setMockMethodCallHandler(ExternalDocuments.channel, null);
  });
  test('platform without adapter leaves picker available', () async {
    final adapter = ExternalDocuments();
    await adapter.start((_) => fail('No incoming files expected'));
    await adapter.release('/tmp/sample.pdf');
    adapter.dispose();
  });
}
