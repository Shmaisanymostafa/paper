import 'library.dart';

enum LibrarySort {
  recent('librarySortRecent'),
  title('librarySortTitle'),
  newest('librarySortNewest');

  const LibrarySort(this.label);
  final String label;
}

/// Presentation-only filtering and stable ordering, never a metadata mutation.
List<PaperDocument> libraryListing(
  Iterable<PaperDocument> documents, {
  required String query,
  required LibrarySort sort,
}) {
  final needle = query.trim().toLowerCase();
  final result = documents
      .where((d) => d.title.toLowerCase().contains(needle))
      .toList();
  result.sort((a, b) {
    final order = switch (sort) {
      LibrarySort.recent => (b.lastOpenedAt ?? b.importedAt).compareTo(
        a.lastOpenedAt ?? a.importedAt,
      ),
      LibrarySort.title => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
      LibrarySort.newest => b.importedAt.compareTo(a.importedAt),
    };
    return order != 0 ? order : a.id.compareTo(b.id);
  });
  return result;
}
