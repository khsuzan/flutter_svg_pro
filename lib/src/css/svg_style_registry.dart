import 'dart:ui';

import '../models/svg_style.dart';

class SvgStyleRegistry {
  final Map<String, SvgStyle> _registry = {};

  void parseAndRegisterCss(String cssContent) {
    final compoundRegExp = RegExp(r'\.([a-zA-Z0-9_-]+(?:\s*,\s*\.[a-zA-Z0-9_-]+)*)\s*\{([^}]+)\}');
    final matches = compoundRegExp.allMatches(cssContent);

    for (var match in matches) {
      final classGroup = match.group(1)!;
      final rulesBlock = match.group(2)!;
      final classNames = classGroup.split(',').map((s) => s.trim().replaceFirst('.', '')).toList();
      final parsedStyle = _parseRules(rulesBlock);

      for (var className in classNames) {
        _registry[className] = parsedStyle;
      }
    }
  }

  SvgStyle resolveStyle(String? className, Map<String, String> inlineAttributes) {
    SvgStyle? baseStyle;
    if (className != null && _registry.containsKey(className)) {
      baseStyle = _registry[className];
    }

    if (inlineAttributes.containsKey('fill') ||
        inlineAttributes.containsKey('stroke') ||
        inlineAttributes.containsKey('stroke-width')) {
      return _parseInlineAndMerge(baseStyle, inlineAttributes);
    }

    return baseStyle ?? SvgStyle();
  }

  SvgStyle _parseRules(String rulesBlock) {
    final rules = rulesBlock.split(';');
    Color fill = const Color(0x00000000);
    Color stroke = const Color(0x00000000);
    double strokeWidth = 1.0;
    bool hasFill = false;
    bool hasStroke = false;

    for (var rule in rules) {
      if (!rule.contains(':')) continue;
      final parts = rule.split(':');
      final key = parts[0].trim();
      final value = parts.sublist(1).join(':').trim();

      switch (key) {
        case 'fill':
          if (value != 'none') {
            fill = _parseColor(value);
            hasFill = true;
          }
          break;
        case 'stroke':
          if (value != 'none') {
            stroke = _parseColor(value);
            hasStroke = true;
          }
          break;
        case 'stroke-width':
          strokeWidth = double.tryParse(value.replaceAll('px', '')) ?? 1.0;
          break;
      }
    }

    return SvgStyle(
      fillPaint: hasFill
          ? (Paint()..color = fill..style = PaintingStyle.fill)
          : null,
      strokePaint: hasStroke
          ? (Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth)
          : null,
      hasFill: hasFill,
      hasStroke: hasStroke,
    );
  }

  Color _parseColor(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('#')) return _parseHexColor(trimmed);
    return const Color(0xFF000000);
  }

  Color _parseHexColor(String hexStr) {
    var cleanHex = hexStr.replaceAll('#', '').trim();
    if (cleanHex.length == 3) {
      cleanHex = cleanHex.split('').map((c) => '$c$c').join();
    }
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    return Color(int.parse(cleanHex, radix: 16));
  }

  SvgStyle _parseInlineAndMerge(SvgStyle? base, Map<String, String> inline) {
    final baseFillPaint = base?.fillPaint;
    final baseStrokePaint = base?.strokePaint;
    final baseHasFill = base?.hasFill ?? false;
    final baseHasStroke = base?.hasStroke ?? false;

    Color fillColor = baseFillPaint?.color ?? const Color(0x00000000);
    Color strokeColor = baseStrokePaint?.color ?? const Color(0x00000000);
    double strokeWidth = baseStrokePaint?.strokeWidth ?? 1.0;
    bool hasFill = baseHasFill;
    bool hasStroke = baseHasStroke;

    if (inline.containsKey('fill')) {
      final fillVal = inline['fill']!;
      if (fillVal == 'none') {
        hasFill = false;
      } else {
        fillColor = _parseColor(fillVal);
        hasFill = true;
      }
    }

    if (inline.containsKey('stroke')) {
      final strokeVal = inline['stroke']!;
      if (strokeVal == 'none') {
        hasStroke = false;
      } else {
        strokeColor = _parseColor(strokeVal);
        hasStroke = true;
      }
    }

    if (inline.containsKey('stroke-width')) {
      strokeWidth = double.tryParse(inline['stroke-width']!.replaceAll('px', '')) ?? strokeWidth;
      if (hasStroke) {
        hasStroke = true;
      }
    }

    return SvgStyle(
      fillPaint: hasFill
          ? (Paint()..color = fillColor..style = PaintingStyle.fill)
          : null,
      strokePaint: hasStroke
          ? (Paint()
            ..color = strokeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth)
          : null,
      hasFill: hasFill,
      hasStroke: hasStroke,
    );
  }
}
