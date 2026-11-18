import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cave_paper/ui/page_thumbnails.dart';

void main() {
  for (final rtl in [false, true]) {
    testWidgets('lazy thumbnails navigate logical page rtl=$rtl', (
      tester,
    ) async {
      final built = <int>{};
      var selected = 1;
      late StateSetter refresh;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: StatefulBuilder(
                  builder: (_, update) {
                    refresh = update;
                    return Scaffold(
                      body: SizedBox(
                        width: 320,
                        height: 480,
                        child: PageThumbnails(
                          pageCount: 1000,
                          currentPage: selected,
                          pageLabel: (page) =>
                              rtl ? 'الصفحة $page' : 'Page $page',
                          previewBuilder: (page) {
                            built.add(page);
                            return const ColoredBox(color: Colors.white);
                          },
                          onSelected: (page) => refresh(() => selected = page),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        expect(built.length, lessThan(10));
        final firstNode = tester.getSemantics(
          find.bySemanticsLabel(rtl ? 'الصفحة 1' : 'Page 1'),
        );
        expect(firstNode.flagsCollection.isButton, isTrue);
        expect(firstNode.flagsCollection.isSelected, Tristate.isTrue);

        await tester.tap(find.text(rtl ? 'الصفحة 1' : 'Page 1'));
        expect(selected, 1);
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(built.length, lessThan(15));
        final later = find.text(rtl ? 'الصفحة 3' : 'Page 3');
        await tester.ensureVisible(later);
        await tester.tap(later);
        await tester.pump();
        expect(selected, 3);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(rtl ? 'الصفحة 3' : 'Page 3'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
