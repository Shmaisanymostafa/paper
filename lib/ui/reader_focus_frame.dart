import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Focus controls never cover modal routes. A visible, labeled escape hatch
/// remains available even when the reader's normal chrome is hidden.
class ReaderFocusFrame extends StatelessWidget {
  const ReaderFocusFrame({
    required this.focused,
    required this.onRestore,
    required this.restoreLabel,
    required this.child,
    super.key,
  });
  final bool focused;
  final VoidCallback onRestore;
  final String restoreLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: focused
        ? {const SingleActivator(LogicalKeyboardKey.escape): onRestore}
        : {},
    child: Focus(
      autofocus: true,
      child: Stack(
        children: [
          child,
          if (focused)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: SafeArea(
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(24),
                  child: IconButton(
                    tooltip: restoreLabel,
                    onPressed: onRestore,
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
