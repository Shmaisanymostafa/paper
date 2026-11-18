import 'package:material_ui/material_ui.dart';

import 'strings.dart';

/// Logical page navigation. Direction-aware icons mirror in RTL, while page
/// numbers keep their meaning: previous always decreases, next increases.
class PageNavigation extends StatelessWidget {
  const PageNavigation({
    required this.page,
    required this.pageCount,
    required this.strings,
    required this.onPrevious,
    required this.onNext,
    required this.onChoose,
    super.key,
  });
  final int page, pageCount;
  final PaperStrings strings;
  final VoidCallback? onPrevious, onNext, onChoose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: strings['previousPage'],
        onPressed: pageCount > 0 && page > 1 ? onPrevious : null,
        icon: const Icon(Icons.arrow_back),
      ),
      Expanded(
        child: TextButton(
          onPressed: pageCount > 0 ? onChoose : null,
          child: Text('${strings['page']} $page ${strings['of']} $pageCount'),
        ),
      ),
      IconButton(
        tooltip: strings['nextPage'],
        onPressed: pageCount > 0 && page < pageCount ? onNext : null,
        icon: const Icon(Icons.arrow_forward),
      ),
    ],
  );
}
