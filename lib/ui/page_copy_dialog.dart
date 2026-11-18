import 'package:material_ui/material_ui.dart';

import 'strings.dart';
import '../services/page_copy.dart';

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
      title: Text(s['copyPages']),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
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
              CheckboxListTile(
                value: agreed,
                onChanged: (v) => setState(() => agreed = v == true),
                title: Text(s['copyPagesAgree']),
              ),
            ],
          ),
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
                    PageCopy.validateSelection(
                      field.text.split(',').map((v) => int.parse(v.trim())),
                      widget.pageCount,
                    );
                    Navigator.pop(context, field.text);
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
