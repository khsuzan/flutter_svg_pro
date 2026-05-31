import 'dart:ui';

import 'package:xml/xml.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:flutter/foundation.dart';

import '../css/svg_style_registry.dart';
import '../models/drawable_path.dart';
import '../models/svg_part.dart';

class SvgParserEngine {
  final SvgStyleRegistry styleRegistry = SvgStyleRegistry();
  Rect viewBox = Rect.zero;

  Future<List<SvgPart>> parseAsync(
    String rawSvgText, {
    String? externalCss,
  }) async {
    if (externalCss != null) styleRegistry.parseAndRegisterCss(externalCss);

    // Conditionally offload to background Isolate.
    // Spawning an isolate (via compute) has a ~100ms setup overhead.
    // For small SVGs (< 50KB), parsing on the main thread takes < 2ms,
    // so we parse synchronously to load instantly without isolate overhead!
    // For large/complex SVGs, we offload to background Isolate to prevent blocking the UI thread.
    final Map<String, dynamic> parseResult;
    if (rawSvgText.length < 51200) {
      parseResult = _parseSvgIsolateBody({'rawSvgText': rawSvgText});
    } else {
      parseResult = await compute(_parseSvgIsolateBody, {
        'rawSvgText': rawSvgText,
      });
    }

    // 1. Register style elements extracted from the isolate
    final cssRules = List<String>.from(parseResult['cssRules']);
    for (var rule in cssRules) {
      styleRegistry.parseAndRegisterCss(rule);
    }

    // 2. Set viewBox
    final viewBoxCoords = List<double>.from(parseResult['viewBox']);
    viewBox = Rect.fromLTWH(
      viewBoxCoords[0],
      viewBoxCoords[1],
      viewBoxCoords[2],
      viewBoxCoords[3],
    );

    // 3. Reconstruct full SvgPart instances (creates native Path and Paint objects very fast)
    final rawParts = parseResult['parts'] as List;
    final discoveredParts = <SvgPart>[];

    for (var rawPart in rawParts) {
      final id = rawPart['id'] as String;
      final name = rawPart['name'] as String;
      final drawablePaths = <DrawablePath>[];

      for (var rawPath in rawPart['paths']) {
        final d = rawPath['d'] as String;
        Path path;
        try {
          path = parseSvgPathData(d);
        } catch (_) {
          continue;
        }

        // Apply accumulated transform
        final transformStorage = List<double>.from(rawPath['transform']);
        final transformedPath = path.transform(
          Float64List.fromList(transformStorage),
        );

        // Resolve style using the main thread's styleRegistry
        final className = rawPath['class'] as String?;
        final inlineAttrs = Map<String, String>.from(rawPath['inlineAttrs']);
        final resolvedStyle = styleRegistry.resolveStyle(
          className,
          inlineAttrs,
        );

        drawablePaths.add(
          DrawablePath(path: transformedPath, style: resolvedStyle),
        );
      }

      if (drawablePaths.isNotEmpty) {
        discoveredParts.add(
          SvgPart(id: id, name: name, drawablePaths: drawablePaths),
        );
      }
    }

    return discoveredParts;
  }
}

/// Pure Dart isolate body that parses the SVG XML and traverses vector paths.
/// Returns ONLY lightweight Dart primitive data structures.
Map<String, dynamic> _parseSvgIsolateBody(Map<String, dynamic> params) {
  final rawSvgText = params['rawSvgText'] as String;
  final document = XmlDocument.parse(rawSvgText);
  final svgRoot = document.findAllElements('svg').first;

  // 1. Parse viewBox
  List<double> viewBoxCoords = [0.0, 0.0, 100.0, 100.0];
  final viewBoxAttr = svgRoot.getAttribute('viewBox');
  if (viewBoxAttr != null) {
    final coords = viewBoxAttr
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();
    if (coords.length >= 4) {
      viewBoxCoords = [coords[0], coords[1], coords[2], coords[3]];
    }
  } else {
    final widthAttr = svgRoot.getAttribute('width');
    final heightAttr = svgRoot.getAttribute('height');
    if (widthAttr != null && heightAttr != null) {
      final w =
          double.tryParse(widthAttr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      final h =
          double.tryParse(heightAttr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      if (w > 0 && h > 0) {
        viewBoxCoords = [0.0, 0.0, w, h];
      }
    }
  }

  // 2. Extract <style> rules
  final styleElements = document.findAllElements('style');
  final cssRules = styleElements.map((el) => el.innerText).toList();

  // 3. Traverse XML nodes recursively
  final parts = <Map<String, dynamic>>[];
  _traverseIsolateNode(svgRoot, Matrix4.identity(), null, null, parts);

  return {'viewBox': viewBoxCoords, 'cssRules': cssRules, 'parts': parts};
}

void _traverseIsolateNode(
  XmlNode node,
  Matrix4 inheritedTransform,
  String? currentPartId,
  String? currentPartName,
  List<Map<String, dynamic>> partsCollector,
) {
  for (var child in node.children) {
    if (child is! XmlElement) continue;

    final localTransform = _parseTransform(child.getAttribute('transform'));
    final accumulatedTransform = inheritedTransform * localTransform;

    if (child.name.local == 'a') {
      final mouseMoveAttr = child.getAttribute('onmousemove') ?? '';
      final extractedName = _extractTooltipLabel(mouseMoveAttr);
      _traverseIsolateNode(
        child,
        accumulatedTransform,
        currentPartId,
        extractedName,
        partsCollector,
      );
      continue;
    }

    if (child.name.local == 'g') {
      final groupId = child.getAttribute('id');
      _traverseIsolateNode(
        child,
        accumulatedTransform,
        groupId ?? currentPartId,
        currentPartName,
        partsCollector,
      );
      continue;
    }

    if (_isGeometricPrimitive(child.name.local)) {
      final id =
          child.getAttribute('id') ??
          currentPartId ??
          'part_${partsCollector.length}';
      final name = currentPartName ?? id;

      final pathData = _convertPrimitiveToPathData(child);
      if (pathData == null || pathData.isEmpty) continue;

      final styleClass = child.getAttribute('class');
      final inlineAttrs = <String, String>{};
      for (var attr in child.attributes) {
        inlineAttrs[attr.name.local] = attr.value;
      }

      final pathMap = {
        'd': pathData,
        'transform': accumulatedTransform.storage.toList(),
        'class': styleClass,
        'inlineAttrs': inlineAttrs,
      };

      final existingPartIndex = partsCollector.indexWhere((p) => p['id'] == id);
      if (existingPartIndex != -1) {
        (partsCollector[existingPartIndex]['paths'] as List).add(pathMap);
      } else {
        partsCollector.add({
          'id': id,
          'name': name,
          'paths': [pathMap],
        });
      }
    }
  }
}

String _extractTooltipLabel(String attrValue) {
  final regExp = RegExp(r"showTooltip\(evt,\s*'([^']+)'\)");
  final match = regExp.firstMatch(attrValue);
  return match != null ? match.group(1)! : '';
}

bool _isGeometricPrimitive(String tagName) {
  return [
    'path',
    'rect',
    'circle',
    'ellipse',
    'polygon',
    'polyline',
  ].contains(tagName);
}

String? _convertPrimitiveToPathData(XmlElement element) {
  final type = element.name.local;
  try {
    if (type == 'path') {
      final d = element.getAttribute('d') ?? '';
      if (d.trim().isEmpty) return null;
      return d;
    }
    if (type == 'rect') {
      final x = double.tryParse(element.getAttribute('x') ?? '0') ?? 0.0;
      final y = double.tryParse(element.getAttribute('y') ?? '0') ?? 0.0;
      final w = double.tryParse(element.getAttribute('width') ?? '0') ?? 0.0;
      final h = double.tryParse(element.getAttribute('height') ?? '0') ?? 0.0;
      return 'M $x $y h $w v $h h -$w Z';
    }
    if (type == 'circle') {
      final cx = double.tryParse(element.getAttribute('cx') ?? '0') ?? 0.0;
      final cy = double.tryParse(element.getAttribute('cy') ?? '0') ?? 0.0;
      final r = double.tryParse(element.getAttribute('r') ?? '0') ?? 0.0;
      return 'M ${cx - r} $cy A $r $r 0 1 0 ${cx + r} $cy A $r $r 0 1 0 ${cx - r} $cy Z';
    }
    if (type == 'ellipse') {
      final cx = double.tryParse(element.getAttribute('cx') ?? '0') ?? 0.0;
      final cy = double.tryParse(element.getAttribute('cy') ?? '0') ?? 0.0;
      final rx = double.tryParse(element.getAttribute('rx') ?? '0') ?? 0.0;
      final ry = double.tryParse(element.getAttribute('ry') ?? '0') ?? 0.0;
      return 'M ${cx - rx} $cy A $rx $ry 0 1 0 ${cx + rx} $cy A $rx $ry 0 1 0 ${cx - rx} $cy Z';
    }
    if (type == 'polygon' || type == 'polyline') {
      final pointsAttr = element.getAttribute('points') ?? '';
      final points = pointsAttr
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => double.tryParse(s))
          .whereType<double>()
          .toList();
      if (points.length < 2) return null;
      final sb = StringBuffer('M ${points[0]} ${points[1]}');
      for (var i = 2; i + 1 < points.length; i += 2) {
        sb.write(' L ${points[i]} ${points[i + 1]}');
      }
      if (type == 'polygon') {
        sb.write(' Z');
      }
      return sb.toString();
    }
  } catch (_) {
    return null;
  }
  return null;
}

Matrix4 _parseTransform(String? transformAttr) {
  if (transformAttr == null || transformAttr.isEmpty) return Matrix4.identity();

  if (transformAttr.startsWith('matrix')) {
    try {
      final cleanValues = transformAttr
          .replaceAll('matrix(', '')
          .replaceAll(')', '')
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => double.tryParse(s))
          .whereType<double>()
          .toList();
      if (cleanValues.length == 6) {
        return Matrix4(
          cleanValues[0],
          cleanValues[1],
          0,
          0,
          cleanValues[2],
          cleanValues[3],
          0,
          0,
          0,
          0,
          1,
          0,
          cleanValues[4],
          cleanValues[5],
          0,
          1,
        );
      }
    } catch (_) {}
  }

  if (transformAttr.startsWith('translate')) {
    try {
      final cleanValues = transformAttr
          .replaceAll('translate(', '')
          .replaceAll(')', '')
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => double.tryParse(s))
          .whereType<double>()
          .toList();
      final tx = cleanValues.isNotEmpty ? cleanValues[0] : 0.0;
      final ty = cleanValues.length > 1 ? cleanValues[1] : 0.0;
      final m = Matrix4.identity();
      m.setTranslationRaw(tx, ty, 0);
      return m;
    } catch (_) {}
  }

  if (transformAttr.startsWith('scale')) {
    try {
      final cleanValues = transformAttr
          .replaceAll('scale(', '')
          .replaceAll(')', '')
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => double.tryParse(s))
          .whereType<double>()
          .toList();
      final sx = cleanValues.isNotEmpty ? cleanValues[0] : 1.0;
      final sy = cleanValues.length > 1 ? cleanValues[1] : sx;
      return Matrix4.diagonal3Values(sx, sy, 1);
    } catch (_) {}
  }

  if (transformAttr.startsWith('rotate')) {
    try {
      final cleanValues = transformAttr
          .replaceAll('rotate(', '')
          .replaceAll(')', '')
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => double.tryParse(s))
          .whereType<double>()
          .toList();
      final a = cleanValues.isNotEmpty ? cleanValues[0] : 0.0;
      final cx = cleanValues.length > 1 ? cleanValues[1] : 0.0;
      final cy = cleanValues.length > 2 ? cleanValues[2] : 0.0;
      final m = Matrix4.identity();
      if (cx != 0.0 || cy != 0.0) {
        m.multiply(Matrix4.translationValues(cx, cy, 0.0));
        m.rotateZ(a * 3.1415926535897932 / 180.0);
        m.multiply(Matrix4.translationValues(-cx, -cy, 0.0));
      } else {
        m.rotateZ(a * 3.1415926535897932 / 180.0);
      }
      return m;
    } catch (_) {}
  }

  return Matrix4.identity();
}
