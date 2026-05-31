import 'package:flutter/material.dart';

import '../models/svg_part.dart';
import '../transformer/svg_viewport_transformation.dart';

/// A custom [CustomPainter] that renders the vector paths of the SVG onto a canvas.
/// 
/// Handles aspect ratio fitting, scale transformations, and renders
/// selected parts with a custom select overlay highlight color.
class SvgCanvasPainter extends CustomPainter {
  /// The list of [SvgPart] elements representing the selectable SVG geometry.
  final List<SvgPart> parts;

  /// The active set of unique identifiers representing currently selected parts.
  final Set<String> selectedIds;

  /// The viewBox limits defined in the parsed SVG.
  final Rect viewBox;

  /// The overlay highlight color used to render selected parts.
  final Color highlightColor;

  /// Creates a canvas painter with the given parameters.
  SvgCanvasPainter({
    required this.parts,
    required this.selectedIds,
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
      final isSelected = selectedIds.contains(part.id);

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
    if (oldDelegate.parts != parts) return true;
    if (oldDelegate.selectedIds.length != selectedIds.length) return true;
    if (oldDelegate.selectedIds.any((id) => !selectedIds.contains(id))) return true;
    return false;
  }
}
