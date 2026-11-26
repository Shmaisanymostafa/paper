// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../domain/library.dart';
import 'strings.dart';

/// Pen line width in PDF points (matches the saved ink annotations).
const penWidthPoints = 2.0;

/// Drops points closer than [minDistance] to the previous kept point, keeps
/// the last point, and caps the stroke at [maxPoints] points.
List<Offset> simplifyStroke(
  List<Offset> points, {
  double minDistance = 1.5,
  int maxPoints = 2000,
}) {
  if (points.length <= 2) return List.of(points);
  final kept = <Offset>[points.first];
  for (final p in points.skip(1)) {
    if ((p - kept.last).distance >= minDistance) kept.add(p);
  }
  if (kept.last != points.last) kept.add(points.last);
  if (kept.length <= maxPoints) return kept;
  // Even thinning keeps the shape of very long strokes.
  final step = kept.length / maxPoints;
  return [
    for (var i = 0; i < maxPoints - 1; i++) kept[(i * step).floor()],
    kept.last,
  ];
}

/// Collects one-finger pen strokes over a page. Pointer events are watched,
/// not claimed, so two-finger zoom still reaches the viewer; a second finger
/// cancels the stroke in progress.
class InkPageOverlay extends StatefulWidget {
  const InkPageOverlay({
    required this.page,
    required this.color,
    required this.onStroke,
    super.key,
  });
  final PdfPage page;
  final int color;

  /// Receives the finished stroke in PDF page coordinates (x0, y0, x1, …).
  final ValueChanged<List<double>> onStroke;

  @override
  State<InkPageOverlay> createState() => _InkPageOverlayState();
}

class _InkPageOverlayState extends State<InkPageOverlay> {
  final _points = ValueNotifier<List<Offset>>(const []);
  final _pointers = <int>{};
  int? _active;

  @override
  void dispose() {
    _points.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    _pointers.add(e.pointer);
    if (_pointers.length == 1) {
      _active = e.pointer;
      _points.value = [e.localPosition];
    } else {
      _cancel();
    }
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _active) return;
    _points.value = [..._points.value, e.localPosition];
  }

  void _up(PointerEvent e, Size size) {
    _pointers.remove(e.pointer);
    if (e.pointer != _active) return;
    _active = null;
    final points = simplifyStroke(_points.value);
    _points.value = const [];
    if (points.length < 2 || e is PointerCancelEvent) return;
    final pdf = <double>[];
    for (final p in points) {
      final clamped = Offset(
        p.dx.clamp(0, size.width),
        p.dy.clamp(0, size.height),
      );
      final point = clamped.toPdfPoint(page: widget.page, scaledPageSize: size);
      pdf
        ..add(point.x)
        ..add(point.y);
    }
    widget.onStroke(pdf);
  }

  void _cancel() {
    _active = null;
    _points.value = const [];
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final scale = size.height / widget.page.height;
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: (e) => _up(e, size),
        onPointerCancel: (e) => _up(e, size),
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _LiveStroke(
              _points,
              Color(0xFF000000 | widget.color),
              penWidthPoints * scale,
            ),
          ),
        ),
      );
    },
  );
}

class _LiveStroke extends CustomPainter {
  _LiveStroke(this.points, this.color, this.width) : super(repaint: points);
  final ValueNotifier<List<Offset>> points;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final p = points.value;
    if (p.length < 2) return;
    canvas.drawPath(Path()..addPolygon(p, false), inkPaint(color, width));
  }

  @override
  bool shouldRepaint(_LiveStroke old) =>
      old.color != color || old.width != width;
}

Paint inkPaint(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Draws saved strokes in the viewer's document coordinates.
void paintInk(Canvas canvas, Rect pageRect, PdfPage page, PaperNote note) {
  final paint = inkPaint(
    Color(0xFF000000 | note.displayColor),
    penWidthPoints * pageRect.height / page.height,
  );
  for (final stroke in note.ink) {
    final path = Path();
    for (var i = 0; i < stroke.points.length; i += 2) {
      final o = PdfPoint(
        stroke.points[i],
        stroke.points[i + 1],
      ).toOffsetInDocument(page: page, pageRect: pageRect);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, paint);
  }
}

/// A row of colour swatches; the chosen one is ringed.
class MarkColorPicker extends StatelessWidget {
  const MarkColorPicker({
    required this.selected,
    required this.onSelected,
    required this.strings,
    super.key,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final PaperStrings strings;

  static const _names = [
    'colorYellow',
    'colorGreen',
    'colorBlue',
    'colorPink',
    'colorRed',
    'colorInk',
  ];

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 4,
      children: [
        for (var i = 0; i < markColors.length; i++)
          Semantics(
            selected: markColors[i] == selected,
            button: true,
            label: strings[_names[i]],
            child: InkResponse(
              key: ValueKey('mark-color-${markColors[i]}'),
              radius: 22,
              onTap: () => onSelected(markColors[i]),
              child: Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: markColors[i] == selected
                        ? ring
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF000000 | markColors[i]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shown instead of the zoom bar while drawing.
class DrawToolbar extends StatelessWidget {
  const DrawToolbar({
    required this.color,
    required this.onColor,
    required this.canUndo,
    required this.onUndo,
    required this.onDone,
    required this.strings,
    super.key,
  });
  final int color;
  final ValueChanged<int> onColor;
  final bool canUndo;
  final VoidCallback onUndo, onDone;
  final PaperStrings strings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: MarkColorPicker(
            selected: color,
            onSelected: onColor,
            strings: strings,
          ),
        ),
      ),
      IconButton(
        tooltip: strings['drawUndo'],
        onPressed: canUndo ? onUndo : null,
        icon: const Icon(Icons.undo),
      ),
      FilledButton(
        key: const Key('draw-done'),
        onPressed: onDone,
        child: Text(strings['drawDone']),
      ),
    ],
  );
}
