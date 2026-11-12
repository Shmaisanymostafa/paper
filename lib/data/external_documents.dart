import 'package:flutter/services.dart';

/// Platform open events are queued until the UI is ready. No OS default changes.
class ExternalDocuments {
  static const channel = MethodChannel('technology.cave.paper/documents');
  Future<void> start(void Function(String) onOpen) async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) {
        onOpen(call.arguments as String);
      }
    });
    try {
      final paths = await channel.invokeListMethod<String>('ready');
      for (final path in paths ?? <String>[]) {
        onOpen(path);
      }
    } on MissingPluginException {
      // Other platform adapters are added independently; picker still works.
    }
  }

  Future<void> release(String path) async {
    try {
      await channel.invokeMethod<void>('release', path);
    } on MissingPluginException {
      // No native resource to release on platforms without the adapter.
    }
  }

  void dispose() => channel.setMethodCallHandler(null);
}
