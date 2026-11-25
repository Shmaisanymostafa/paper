// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import 'strings.dart';

class NoteEditorDialog extends StatefulWidget {
  const NoteEditorDialog({
    required this.title,
    required this.strings,
    this.initialText = '',
    this.allowEmpty = false,
    super.key,
  });
  final String title, initialText;
  final PaperStrings strings;
  final bool allowEmpty;
  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  late final field = TextEditingController(text: widget.initialText);
  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final valid =
        (widget.allowEmpty || field.text.trim().isNotEmpty) &&
        field.text.trim().length <= 10000;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: field,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 10000,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: s['note']),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s['cancel']),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, field.text.trim())
              : null,
          child: Text(s['save']),
        ),
      ],
    );
  }
}
