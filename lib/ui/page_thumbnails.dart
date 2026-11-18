import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:material_ui/material_ui.dart';

/// Lazy, bounded previews. The reader supplies images from its already-open
/// document; this list neither opens files nor changes document data.
class PageThumbnails extends StatelessWidget {
  const PageThumbnails({
    required this.pageCount,
    required this.currentPage,
    required this.pageLabel,
    required this.previewBuilder,
    required this.onSelected,
    super.key,
  });
  final int pageCount, currentPage;
  final String Function(int) pageLabel;
  final Widget Function(int) previewBuilder;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => ListView.builder(
    scrollCacheExtent: const ScrollCacheExtent.pixels(0),
    addAutomaticKeepAlives: false,
    padding: const EdgeInsets.all(12),
    itemCount: pageCount,
    itemBuilder: (context, index) {
      final page = index + 1;
      final selected = page == currentPage;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          button: true,
          selected: selected,
          label: pageLabel(page),
          child: Material(
            color: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(page),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(height: 144, child: previewBuilder(page)),
                    ),
                    const SizedBox(height: 8),
                    ExcludeSemantics(
                      child: Text(pageLabel(page), textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
