import 'dart:ui';
import 'dart:math' as math;

import 'package:xml/xml.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:flutter/foundation.dart';

import '../css/svg_style_registry.dart';
import '../models/drawable_path.dart';
import '../models/svg_part.dart';

/// An isolate-aware, high-performance engine that parses SVG XML content.
/// 
/// Resolves elements, inherits transformations, parses CSS stylesheets,
/// and maps geometric vector paths to structured, selectable [SvgPart] units.
class SvgParserEngine {
  /// The resolved cascading styling stylesheet registry.
  final SvgStyleRegistry styleRegistry = SvgStyleRegistry();

  /// The viewport bounds of the SVG, loaded dynamically from the `viewBox` attribute.
  Rect viewBox = Rect.zero;

  /// Parses the raw SVG text asynchronously and resolves styling and selectable components.
  /// 
  /// Optionally registers an [externalCss] stylesheet string.
  /// Blazing-fast setup uses a hybrid threshold: small SVGs (<50KB) parse instantly on the main thread,
  /// while large SVGs execute inside a background isolate to keep the UI running at 120 FPS.
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
      final isSelectable = rawPart['isSelectable'] as bool? ?? true;
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
          SvgPart(
            id: id,
            name: name,
            drawablePaths: drawablePaths,
            isSelectable: isSelectable,
          ),
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

  // 3. Collect defs for <use> tags
  final defsMap = <String, XmlElement>{};
  for (var element in document.findAllElements('*')) {
    final id = element.getAttribute('id');
    if (id != null) defsMap[id] = element;
  }

  // 4. Root transforms
  var rootTransformAttr = svgRoot.getAttribute('transform');
  final rootStyleAttr = svgRoot.getAttribute('style');
  if (rootStyleAttr != null && rootStyleAttr.contains('transform:')) {
    final cssTransformMatch = RegExp(r'transform:\s*([^;]+)').firstMatch(rootStyleAttr);
    if (cssTransformMatch != null) {
      rootTransformAttr = (rootTransformAttr == null ? '' : rootTransformAttr + ' ') + cssTransformMatch.group(1)!;
    }
  }
  final rootTransform = _parseTransform(rootTransformAttr);

  // 5. Traverse XML nodes recursively
  final parts = <Map<String, dynamic>>[];
  _traverseIsolateNode(svgRoot, rootTransform, null, null, parts, defsMap);

  return {'viewBox': viewBoxCoords, 'cssRules': cssRules, 'parts': parts};
}

void _traverseIsolateNode(
  XmlNode node,
  Matrix4 inheritedTransform,
  String? currentPartId,
  String? currentPartName,
  List<Map<String, dynamic>> partsCollector,
  Map<String, XmlElement> defsMap,
) {
  for (var child in node.children) {
    if (child is! XmlElement) continue;

    var transformAttr = child.getAttribute('transform');
    final styleAttr = child.getAttribute('style');
    if (styleAttr != null && styleAttr.contains('transform:')) {
      final cssTransformMatch = RegExp(r'transform:\s*([^;]+)').firstMatch(styleAttr);
      if (cssTransformMatch != null) {
        transformAttr = (transformAttr == null ? '' : transformAttr + ' ') + cssTransformMatch.group(1)!;
      }
    }

    final localTransform = _parseTransform(transformAttr);
    final accumulatedTransform = inheritedTransform * localTransform;

    if (child.name.local == 'use') {
      final href = child.getAttribute('href') ?? child.getAttribute('xlink:href');
      if (href != null && href.startsWith('#')) {
        final targetId = href.substring(1);
        final targetElement = defsMap[targetId];
        if (targetElement != null) {
          final useX = double.tryParse(child.getAttribute('x') ?? '0') ?? 0.0;
          final useY = double.tryParse(child.getAttribute('y') ?? '0') ?? 0.0;
          final useTransform = accumulatedTransform.clone();
          if (useX != 0.0 || useY != 0.0) {
            useTransform.multiply(Matrix4.translationValues(useX, useY, 0.0));
          }
          final dummyGroup = XmlElement(XmlName('g'));
          dummyGroup.children.add(targetElement.copy());
          _traverseIsolateNode(
            dummyGroup,
            useTransform,
            child.getAttribute('id') ?? currentPartId,
            currentPartName,
            partsCollector,
            defsMap,
          );
        }
      }
      continue;
    }

    if (child.name.local == 'a') {
      final mouseMoveAttr = child.getAttribute('onmousemove') ?? '';
      final extractedName = _extractTooltipLabel(mouseMoveAttr);
      _traverseIsolateNode(
        child,
        accumulatedTransform,
        currentPartId,
        extractedName,
        partsCollector,
        defsMap,
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
        defsMap,
      );
      continue;
    }

    if (_isGeometricPrimitive(child.name.local)) {
      final hasExplicitId = child.getAttribute('id') != null || currentPartId != null;
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
        if (hasExplicitId) {
          partsCollector[existingPartIndex]['isSelectable'] = true;
        }
      } else {
        partsCollector.add({
          'id': id,
          'name': name,
          'isSelectable': hasExplicitId,
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
    'line',
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
    if (type == 'line') {
      final x1 = double.tryParse(element.getAttribute('x1') ?? '0') ?? 0.0;
      final y1 = double.tryParse(element.getAttribute('y1') ?? '0') ?? 0.0;
      final x2 = double.tryParse(element.getAttribute('x2') ?? '0') ?? 0.0;
      final y2 = double.tryParse(element.getAttribute('y2') ?? '0') ?? 0.0;
      return 'M $x1 $y1 L $x2 $y2';
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

  final m = Matrix4.identity();
  final regExp = RegExp(r'(matrix|translate|scale|rotate|skewX|skewY)\s*\(([^)]*)\)');
  final matches = regExp.allMatches(transformAttr);

  for (final match in matches) {
    final type = match.group(1);
    // Replace minus signs with " -" to handle compressed SVGs like translate(100-200)
    // using (?<![eE]) to prevent breaking scientific notation like 1e-5
    final argsStr = (match.group(2) ?? '').replaceAll(RegExp(r'(?<![eE])-'), ' -');
    final args = argsStr
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();

    if (type == 'matrix') {
      if (args.length >= 6) {
        final matrix = Matrix4(
          args[0], args[1], 0, 0,
          args[2], args[3], 0, 0,
          0, 0, 1, 0,
          args[4], args[5], 0, 1,
        );
        m.multiply(matrix);
      }
    } else if (type == 'translate') {
      final tx = args.isNotEmpty ? args[0] : 0.0;
      final ty = args.length > 1 ? args[1] : 0.0;
      final trans = Matrix4.identity()..setTranslationRaw(tx, ty, 0);
      m.multiply(trans);
    } else if (type == 'scale') {
      final sx = args.isNotEmpty ? args[0] : 1.0;
      final sy = args.length > 1 ? args[1] : sx;
      m.multiply(Matrix4.diagonal3Values(sx, sy, 1));
    } else if (type == 'rotate') {
      final a = args.isNotEmpty ? args[0] : 0.0;
      final cx = args.length > 1 ? args[1] : 0.0;
      final cy = args.length > 2 ? args[2] : 0.0;
      final rot = Matrix4.identity();
      if (cx != 0.0 || cy != 0.0) {
        rot.multiply(Matrix4.translationValues(cx, cy, 0.0));
        rot.rotateZ(a * math.pi / 180.0);
        rot.multiply(Matrix4.translationValues(-cx, -cy, 0.0));
      } else {
        rot.rotateZ(a * math.pi / 180.0);
      }
      m.multiply(rot);
    } else if (type == 'skewX') {
      final a = args.isNotEmpty ? args[0] : 0.0;
      final skew = Matrix4.identity();
      skew.setEntry(0, 1, math.tan(a * math.pi / 180.0));
      m.multiply(skew);
    } else if (type == 'skewY') {
      final a = args.isNotEmpty ? args[0] : 0.0;
      final skew = Matrix4.identity();
      skew.setEntry(1, 0, math.tan(a * math.pi / 180.0));
      m.multiply(skew);
    }
  }

  return m;
}
