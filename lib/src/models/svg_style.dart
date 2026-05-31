import 'dart:ui';

/// Represents the resolved vector styling attributes of an SVG element.
class SvgStyle {
  /// The [Paint] object representing the resolved background/fill styling.
  final Paint? fillPaint;

  /// The [Paint] object representing the resolved border/stroke styling.
  final Paint? strokePaint;

  /// Whether this element has a valid background fill color.
  final bool hasFill;

  /// Whether this element has a valid border stroke.
  final bool hasStroke;

  /// Creates a new [SvgStyle] with the given parameters.
  SvgStyle({
    this.fillPaint,
    this.strokePaint,
    this.hasFill = false,
    this.hasStroke = false,
  });
}
