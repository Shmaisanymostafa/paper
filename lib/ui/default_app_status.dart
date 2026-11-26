// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../services/default_pdf_app.dart';
import 'strings.dart';

/// Says which app opens PDFs now (Android) and links to its settings page so
/// the person can clear that default. Checks again when they come back.
class DefaultAppStatus extends StatefulWidget {
  const DefaultAppStatus({required this.app, required this.strings, super.key});
  final DefaultPdfApp app;
  final PaperStrings strings;

  @override
  State<DefaultAppStatus> createState() => _DefaultAppStatusState();
}

class _DefaultAppStatusState extends State<DefaultAppStatus> {
  late final AppLifecycleListener _lifecycle;
  PdfHandler? _handler;
  bool _loaded = false;
  int _check = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final check = ++_check;
    final handler = await widget.app.currentHandler();
    if (!mounted || check != _check) return;
    setState(() {
      _handler = handler;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final theme = Theme.of(context);
    if (!_loaded) return const SizedBox(height: 8);
    final handler = _handler;
    final Widget body;
    if (handler == null) {
      body = Text(s['defaultAppNone'], key: const Key('default-app-none'));
    } else if (handler.isSelf) {
      body = Row(
        key: const Key('default-app-self'),
        children: [
          Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(s['defaultAppIsCave'])),
        ],
      );
    } else {
      body = Column(
        key: const Key('default-app-other'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s['defaultAppCurrent'].replaceAll('{app}', handler.label),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(s['defaultAppClearSteps'].replaceAll('{app}', handler.label)),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.settings_outlined),
            label: Text(
              s['defaultAppOpenHandler'].replaceAll('{app}', handler.label),
            ),
            onPressed: () async {
              final opened = await widget.app.openHandlerSettings(handler);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s['defaultAppHandlerError'])),
                );
              }
            },
          ),
        ],
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: body);
  }
}
