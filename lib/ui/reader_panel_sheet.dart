import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Keeps the reader's mobile tools above the software keyboard, without
/// changing the underlying document viewport or dismissing the keyboard.
class ReaderPanelSheet extends StatelessWidget {
  const ReaderPanelSheet({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = math.max(
      0.0,
      media.size.height - media.viewInsets.bottom - media.padding.top,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: math.min(media.size.height * .8, available),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The real panel has tabs, search input and match navigation above
              // an Expanded list. Scroll the whole panel if the keyboard leaves
              // less room than those controls need, instead of squeezing them.
              final minimum = 360.0 * media.textScaler.scale(1);
              return ClipRect(
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: math.max(constraints.maxHeight, minimum),
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
