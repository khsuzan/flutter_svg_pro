import 'dart:ui';

import '../models/svg_style.dart';

/// A central registry for parsing, storing, and resolving SVG style selectors.
///
/// Resolves cascading styling precedence: inline style attributes override
/// embedded stylesheet classes, which override global/default styles.
class SvgStyleRegistry {
  final Map<String, SvgStyle> _registry = {};

  /// Parses raw CSS content and registers selector rules into this stylesheet registry.
  void parseAndRegisterCss(String cssContent) {
    final noComments = cssContent.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    final blockRegExp = RegExp(r'([^\{\}]+)\{([^}]+)\}');
    final matches = blockRegExp.allMatches(noComments);

    for (var match in matches) {
      final selectorsString = match.group(1)!.trim();
      final rulesBlock = match.group(2)!;

      if (selectorsString.startsWith('@')) continue;

      final selectors = selectorsString.split(',');
      final parsedStyle = _parseRules(rulesBlock);

      for (var selector in selectors) {
        selector = selector.trim();
        if (selector.startsWith('.') &&
            !selector.contains(' ') &&
            !selector.contains(':') &&
            !selector.contains('>')) {
          final className = selector.replaceFirst('.', '');
          _registry[className] = parsedStyle;
        }
      }
    }
  }

  /// Resolves the final cascading [SvgStyle] for an element.
  ///
  /// Merges optional stylesheet [className] properties with [inlineAttributes]
  /// following standard CSS precedence order.
  SvgStyle resolveStyle(
    String? className,
    Map<String, String> inlineAttributes,
  ) {
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
    double opacity = 1.0;

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
        case 'opacity':
          opacity = double.tryParse(value) ?? 1.0;
          break;
      }
    }

    if (opacity < 1.0) {
      fill = fill.withValues(alpha: opacity);
      stroke = stroke.withValues(alpha: opacity);
    }

    return SvgStyle(
      fillPaint: hasFill
          ? (Paint()
              ..color = fill
              ..style = PaintingStyle.fill)
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
    double opacity = 1.0;

    if (inline.containsKey('opacity')) {
      opacity = double.tryParse(inline['opacity']!) ?? 1.0;
    }

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
      strokeWidth =
          double.tryParse(inline['stroke-width']!.replaceAll('px', '')) ??
          strokeWidth;
      if (hasStroke) {
        hasStroke = true;
      }
    }

    if (opacity < 1.0) {
      fillColor = fillColor.withValues(alpha: opacity);
      strokeColor = strokeColor.withValues(alpha: opacity);
    }

    return SvgStyle(
      fillPaint: hasFill
          ? (Paint()
              ..color = fillColor
              ..style = PaintingStyle.fill)
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
