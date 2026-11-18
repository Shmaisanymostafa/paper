import 'package:material_ui/material_ui.dart';

import 'strings.dart';
import '../services/page_copy.dart';

class PageCopyRequest {
  PageCopyRequest(Iterable<int> pages, this.clockwiseQuarterTurns)
    : pages = List.unmodifiable(pages);
  final List<int> pages;
  final int clockwiseQuarterTurns;
}

class PageCopyDialog extends StatefulWidget {
  const PageCopyDialog({
    required this.page,
    required this.pageCount,
    required this.strings,
    super.key,
  });
  final int page, pageCount;
  final PaperStrings strings;
  @override
  State<PageCopyDialog> createState() => _PageCopyDialogState();
}

class _PageCopyDialogState extends State<PageCopyDialog> {
  late final field = TextEditingController(text: '${widget.page}');
  bool agreed = false;
  int rotation = 0;
  String? error;
  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      scrollable: true,
      title: Text(s['copyPages']),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s['copyPagesWarning']),
            const SizedBox(height: 16),
            TextField(
              controller: field,
              onChanged: (_) => setState(() => error = null),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: s['pageSequence'],
                errorText: error,
                helperText: s['pageSequenceHint'],
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: rotation,
              isExpanded: true,
              decoration: InputDecoration(labelText: s['pageRotation']),
              items: [
                for (final value in [0, 1, 2, 3])
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      s['pageRotation$value'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => rotation = value);
              },
            ),
            const SizedBox(height: 8),
            Text(s['pageRotationHint']),
            CheckboxListTile(
              value: agreed,
              onChanged: (v) => setState(() => agreed = v == true),
              title: Text(s['copyPagesAgree']),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s['cancel']),
        ),
        FilledButton(
          onPressed: agreed
              ? () {
                  try {
                    final pages = PageCopy.validateSelection(
                      field.text.split(',').map((v) => int.parse(v.trim())),
                      widget.pageCount,
                    );
                    Navigator.pop(context, PageCopyRequest(pages, rotation));
                  } catch (_) {
                    setState(() => error = s['copyPageSelectionError']);
                  }
                }
              : null,
          child: Text(s['saveCopy']),
        ),
      ],
    );
  }
}
