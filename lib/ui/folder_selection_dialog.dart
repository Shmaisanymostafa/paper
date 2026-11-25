// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../services/folder_discovery.dart';
import 'strings.dart';

/// Explicit selection only. No file access, import, persistence or permission
/// grants. The caller must revalidate candidates before importing their bytes.
class FolderSelectionDialog extends StatefulWidget {
  FolderSelectionDialog({
    required Iterable<FolderPdfCandidate> candidates,
    required this.strings,
    required this.incomplete,
    this.maxSelection = 20,
    super.key,
  }) : candidates = List.unmodifiable(candidates.take(5001)) {
    if (maxSelection < 1 || maxSelection > 100) {
      throw ArgumentError.value(maxSelection, 'maxSelection');
    }
    if (this.candidates.length > 5000 ||
        this.candidates.map((e) => e.path).toSet().length !=
            this.candidates.length) {
      throw ArgumentError('Invalid candidate set');
    }
  }
  final List<FolderPdfCandidate> candidates;
  final PaperStrings strings;
  final bool incomplete;
  final int maxSelection;
  @override
  State<FolderSelectionDialog> createState() => _FolderSelectionDialogState();
}

class _FolderSelectionDialogState extends State<FolderSelectionDialog> {
  final selected = <String>{};
  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.candidates.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['folderSelectTitle'],
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(s['folderSelectHint']),
                        if (widget.incomplete)
                          Text(s['folderSelectIncomplete']),
                        if (widget.candidates.isEmpty)
                          Text(s['folderSelectEmpty']),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  final candidate = widget.candidates[index - 1];
                  final checked = selected.contains(candidate.path);
                  return CheckboxListTile(
                    key: ValueKey(candidate.path),
                    title: Text(p.basename(candidate.path)),
                    value: checked,
                    onChanged: checked || selected.length < widget.maxSelection
                        ? (value) => setState(() {
                            if (value == true) {
                              selected.add(candidate.path);
                            } else {
                              selected.remove(candidate.path);
                            }
                          })
                        : null,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${selected.length}/${widget.maxSelection}',
                    semanticsLabel:
                        '${s['folderSelectCount']}: ${selected.length}/${widget.maxSelection}',
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(s['cancel']),
                  ),
                  FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            List<FolderPdfCandidate>.unmodifiable(
                              widget.candidates.where(
                                (c) => selected.contains(c.path),
                              ),
                            ),
                          ),
                    child: Text(s['folderSelectConfirm']),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
