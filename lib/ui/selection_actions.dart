// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

/// Extends, rather than replaces, the viewer's permission-aware Copy/Select All
/// menu. These actions create local sidecar annotations, not edited PDF bytes.
void appendSelectionActions(
  List<ContextMenuButtonItem> items, {
  required bool enabled,
  required String highlightLabel,
  required String noteLabel,
  required VoidCallback onHighlight,
  required VoidCallback onNote,
}) {
  if (!enabled) return;
  items.addAll([
    ContextMenuButtonItem(label: highlightLabel, onPressed: onHighlight),
    ContextMenuButtonItem(label: noteLabel, onPressed: onNote),
  ]);
}

/// A selection can change while the PDF engine loads page text. Validate the
/// captured selection/viewer state after lookup and allow only one lookup at a
/// time. The caller owns liveness, permission and generation checks.
class SelectionActionSession {
  bool _busy = false;

  Future<void> run<T>({
    required Future<T> Function() read,
    required bool Function() isCurrent,
    required Future<void> Function(T value) apply,
  }) async {
    if (_busy || !isCurrent()) return;
    _busy = true;
    try {
      final value = await read();
      if (isCurrent()) await apply(value);
    } finally {
      _busy = false;
    }
  }
}
