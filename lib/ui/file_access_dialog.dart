// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import 'strings.dart';

/// Explains the existing system picker. It requests no filesystem permission
/// itself, and cancel returns without invoking a picker or changing the library.
class FileAccessDialog extends StatelessWidget {
  const FileAccessDialog({required this.strings, super.key});
  final PaperStrings strings;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(strings['fileAccessTitle']),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings['fileAccessSelection']),
          const SizedBox(height: 12),
          Text(strings['fileAccessCopy']),
          const SizedBox(height: 12),
          Text(strings['fileAccessOffline']),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(strings['cancel']),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(strings['fileAccessChoose']),
      ),
    ],
  );
}
