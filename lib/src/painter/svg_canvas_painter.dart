import 'package:flutter/material.dart';

import '../models/svg_part.dart';
import '../transformer/svg_viewport_transformation.dart';

class SvgCanvasPainter extends CustomPainter {
  final List<SvgPart> parts;
  final String? selectedId;
  final Rect viewBox;
  final Color highlightColor;

  SvgCanvasPainter({
    required this.parts,
    required this.selectedId,
    required this.viewBox,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (viewBox == Rect.zero) return;

    final transformer = SvgViewportTransformation(viewBox: viewBox, canvasLayoutSize: size);

    canvas.save();
    canvas.translate(transformer.translationOffset.dx, transformer.translationOffset.dy);
    canvas.scale(transformer.totalScale);
    canvas.translate(-viewBox.left, -viewBox.top);

    for (var part in parts) {
      final isSelected = part.id == selectedId;

      for (var drawable in part.drawablePaths) {
        if (drawable.style.hasFill) {
          if (isSelected) {
            final selectPaint = Paint()
              ..color = highlightColor
              ..style = PaintingStyle.fill;
            canvas.drawPath(drawable.path, selectPaint);
          } else {
            canvas.drawPath(drawable.path, drawable.style.fillPaint!);
          }
        }

        if (drawable.style.hasStroke) {
          canvas.drawPath(drawable.path, drawable.style.strokePaint!);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SvgCanvasPainter oldDelegate) {
    return oldDelegate.selectedId != selectedId || oldDelegate.parts != parts;
  }
}
