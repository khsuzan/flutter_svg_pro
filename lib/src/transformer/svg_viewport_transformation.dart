import 'dart:ui';

class SvgViewportTransformation {
  final Rect viewBox;
  final Size canvasLayoutSize;
  late final double scaleX;
  late final double scaleY;
  late final double totalScale;
  late final Offset translationOffset;

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

  Offset screenToVectorSpace(Offset screenPosition) {
    return Offset(
      ((screenPosition.dx - translationOffset.dx) / totalScale) + viewBox.left,
      ((screenPosition.dy - translationOffset.dy) / totalScale) + viewBox.top,
    );
  }
}
