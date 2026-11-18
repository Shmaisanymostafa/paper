import 'package:cave_paper/services/page_copy.dart';
import 'package:cave_paper/domain/library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'page selection preserves order and duplicates without sharing input',
    () {
      final input = [3, 1, 3];
      final result = PageCopy.validateSelection(input, 3);
      input.clear();
      expect(result, [3, 1, 3]);
      expect(() => result.add(2), throwsUnsupportedError);
    },
  );
  test('invalid, empty and excessive selections fail before native work', () {
    for (final input in <List<int>>[
      [],
      [0],
      [-1],
      [4],
      List.filled(1001, 1),
    ]) {
      expect(
        () => PageCopy.validateSelection(input, 3),
        throwsA(isA<LibraryFormatException>()),
      );
    }
    expect(PageCopy.validateSelection(List.filled(1000, 1), 3).length, 1000);
  });
}
