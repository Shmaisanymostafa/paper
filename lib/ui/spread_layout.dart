// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:math';
import 'dart:ui';

import 'package:pdfrx/pdfrx.dart';

/// Two pages side by side, like an open book: pages 1–2, 3–4, … Each row is
/// as tall as its taller page and centred; the last page may sit alone.
/// [rtl] puts the first page of each pair on the right (Arabic books).
({List<Rect> pages, Size size}) spreadRects(
  List<Size> sizes, {
  required double margin,
  bool rtl = false,
}) {
  if (sizes.isEmpty) return (pages: const <Rect>[], size: Size.zero);
  var width = 0.0;
  for (var i = 0; i < sizes.length; i += 2) {
    final second = i + 1 < sizes.length ? sizes[i + 1].width : sizes[i].width;
    width = max(width, sizes[i].width + second);
  }
  width += margin * 3;
  final rects = <Rect>[];
  var y = margin;
  for (var i = 0; i < sizes.length; i += 2) {
    final pair = [sizes[i], if (i + 1 < sizes.length) sizes[i + 1]];
    final rowHeight = pair.map((s) => s.height).reduce(max);
    final rowWidth =
        pair.map((s) => s.width).reduce((a, b) => a + b) +
        margin * (pair.length - 1);
    var x = (width - rowWidth) / 2;
    final placed = <Rect>[];
    for (final size in rtl ? pair.reversed : pair) {
      placed.add(
        Rect.fromLTWH(
          x,
          y + (rowHeight - size.height) / 2,
          size.width,
          size.height,
        ),
      );
      x += size.width + margin;
    }
    rects.addAll(rtl ? placed.reversed : placed);
    y += rowHeight + margin;
  }
  return (pages: rects, size: Size(width, y));
}

/// [PdfViewerParams.layoutPages] for the two-page view.
PdfPageLayoutFunction spreadLayout({bool rtl = false}) => (pages, params) {
  final result = spreadRects(
    [for (final page in pages) Size(page.width, page.height)],
    margin: params.margin,
    rtl: rtl,
  );
  return PdfPageLayout(pageLayouts: result.pages, documentSize: result.size);
};
