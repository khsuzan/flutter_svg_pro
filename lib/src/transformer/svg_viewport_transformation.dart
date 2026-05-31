import 'dart:ui';

/// Manages viewport coordinate mapping between screen layout coordinates and SVG vector space coordinates.
class SvgViewportTransformation {
  /// The viewBox limits defined in the parsed SVG.
  final Rect viewBox;

  /// The physical canvas constraints/size allocated for rendering the SVG.
  final Size canvasLayoutSize;

  /// The horizontal scaling factor calculated.
  late final double scaleX;

  /// The vertical scaling factor calculated.
  late final double scaleY;

  /// The uniform scaling factor applied to fit the viewBox inside the canvas.
  late final double totalScale;

  /// The centered offset translation applied to the SVG canvas.
  late final Offset translationOffset;

  /// Creates a viewport transformation calculator mapping [viewBox] to [canvasLayoutSize].
  SvgViewportTransformation({
    required this.viewBox,
    required this.canvasLayoutSize,
  }) {
    scaleX = canvasLayoutSize.width / viewBox.width;
    scaleY = canvasLayoutSize.height / viewBox.height;
    totalScale = scaleX < scaleY ? scaleX : scaleY;
    final centeredX = (canvasLayoutSize.width - (viewBox.width * totalScale)) / 2;
    final centeredY = (canvasLayoutSize.height - (viewBox.height * totalScale)) / 2;
    translationOffset = Offset(centeredX, centeredY);
  }

  /// Maps a tapped screen position [screenPosition] back into standard SVG vector space coordinates.
  Offset screenToVectorSpace(Offset screenPosition) {
    return Offset(
      ((screenPosition.dx - translationOffset.dx) / totalScale) + viewBox.left,
      ((screenPosition.dy - translationOffset.dy) / totalScale) + viewBox.top,
    );
  }
}
