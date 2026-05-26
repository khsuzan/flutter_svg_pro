import 'dart:ui';

class SvgStyle {
  final Paint? fillPaint;
  final Paint? strokePaint;
  final bool hasFill;
  final bool hasStroke;

  SvgStyle({
    this.fillPaint,
    this.strokePaint,
    this.hasFill = false,
    this.hasStroke = false,
  });
}
