import 'dart:ui';

import 'package:xml/xml.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:path_drawing/path_drawing.dart';

import '../css/svg_style_registry.dart';
import '../models/drawable_path.dart';
import '../models/svg_part.dart';

class SvgParserEngine {
  final SvgStyleRegistry styleRegistry = SvgStyleRegistry();
  Rect viewBox = Rect.zero;

  List<SvgPart> parse(String rawSvgText, {String? externalCss}) {
    if (externalCss != null) styleRegistry.parseAndRegisterCss(externalCss);

    final document = XmlDocument.parse(rawSvgText);
    final svgRoot = document.findAllElements('svg').first;

    final viewBoxAttr = svgRoot.getAttribute('viewBox');
    if (viewBoxAttr != null) {
      final coords = viewBoxAttr.split(RegExp(r'[\s,]+')).map(double.parse).toList();
      if (coords.length >= 4) {
        viewBox = Rect.fromLTWH(coords[0], coords[1], coords[2], coords[3]);
      }
    } else {
      final widthAttr = svgRoot.getAttribute('width');
      final heightAttr = svgRoot.getAttribute('height');
      if (widthAttr != null && heightAttr != null) {
        final w = double.tryParse(widthAttr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        final h = double.tryParse(heightAttr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        if (w > 0 && h > 0) {
          viewBox = Rect.fromLTWH(0, 0, w, h);
        }
      }
    }

    if (viewBox == Rect.zero) {
      viewBox = const Rect.fromLTWH(0, 0, 100, 100);
    }

    final styleElements = document.findAllElements('style');
    for (var styleElement in styleElements) {
      styleRegistry.parseAndRegisterCss(styleElement.innerText);
    }

    final discoveredParts = <SvgPart>[];
    _traverseNode(svgRoot, Matrix4.identity(), null, null, discoveredParts);
    return discoveredParts;
  }

  void _traverseNode(
    XmlNode node,
    Matrix4 inheritedTransform,
    String? currentPartId,
    String? currentPartName,
    List<SvgPart> partsCollector,
  ) {
    for (var child in node.children) {
      if (child is! XmlElement) continue;

      final localTransform = _parseTransform(child.getAttribute('transform'));
      final accumulatedTransform = inheritedTransform * localTransform;

      if (child.name.local == 'a') {
        final mouseMoveAttr = child.getAttribute('onmousemove') ?? '';
        final extractedName = _extractTooltipLabel(mouseMoveAttr);
        _traverseNode(child, accumulatedTransform, currentPartId, extractedName, partsCollector);
        continue;
      }

      if (child.name.local == 'g') {
        final groupId = child.getAttribute('id');
        _traverseNode(
          child,
          accumulatedTransform,
          groupId ?? currentPartId,
          currentPartName,
          partsCollector,
        );
        continue;
      }

      if (_isGeometricPrimitive(child.name.local)) {
        final id = child.getAttribute('id') ?? currentPartId ?? 'part_${partsCollector.length}';
        final name = currentPartName ?? id;

        final path = _convertPrimitiveToPath(child);
        if (path == null) continue;

        final flattenedPath = path.transform(accumulatedTransform.storage);
        final styleClass = child.getAttribute('class');

        final inlineAttrs = <String, String>{};
        for (var attr in child.attributes) {
          inlineAttrs[attr.name.local] = attr.value;
        }

        final resolvedStyle = styleRegistry.resolveStyle(styleClass, inlineAttrs);
        final drawablePath = DrawablePath(path: flattenedPath, style: resolvedStyle);

        final existingPartIndex = partsCollector.indexWhere((p) => p.id == id);
        if (existingPartIndex != -1) {
          partsCollector[existingPartIndex].drawablePaths.add(drawablePath);
        } else {
          partsCollector.add(SvgPart(
            id: id,
            name: name,
            drawablePaths: [drawablePath],
          ));
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
    return ['path', 'rect', 'circle', 'ellipse', 'polygon', 'polyline'].contains(tagName);
  }

  Path? _convertPrimitiveToPath(XmlElement element) {
    final type = element.name.local;
    try {
      if (type == 'path') {
        final d = element.getAttribute('d') ?? '';
        if (d.trim().isEmpty) return null;
        return parseSvgPathData(d);
      }
      if (type == 'rect') {
        final x = double.tryParse(element.getAttribute('x') ?? '0') ?? 0.0;
        final y = double.tryParse(element.getAttribute('y') ?? '0') ?? 0.0;
        final w = double.tryParse(element.getAttribute('width') ?? '0') ?? 0.0;
        final h = double.tryParse(element.getAttribute('height') ?? '0') ?? 0.0;
        return Path()..addRect(Rect.fromLTWH(x, y, w, h));
      }
      if (type == 'circle') {
        final cx = double.tryParse(element.getAttribute('cx') ?? '0') ?? 0.0;
        final cy = double.tryParse(element.getAttribute('cy') ?? '0') ?? 0.0;
        final r = double.tryParse(element.getAttribute('r') ?? '0') ?? 0.0;
        return Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      }
      if (type == 'ellipse') {
        final cx = double.tryParse(element.getAttribute('cx') ?? '0') ?? 0.0;
        final cy = double.tryParse(element.getAttribute('cy') ?? '0') ?? 0.0;
        final rx = double.tryParse(element.getAttribute('rx') ?? '0') ?? 0.0;
        final ry = double.tryParse(element.getAttribute('ry') ?? '0') ?? 0.0;
        return Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));
      }
      if (type == 'polygon' || type == 'polyline') {
        final pointsAttr = element.getAttribute('points') ?? '';
        final points = pointsAttr
            .split(RegExp(r'[\s,]+'))
            .where((s) => s.isNotEmpty)
            .map(double.parse)
            .toList();
        if (points.length < 2) return null;
        final path = Path();
        path.moveTo(points[0], points[1]);
        for (var i = 2; i + 1 < points.length; i += 2) {
          path.lineTo(points[i], points[i + 1]);
        }
        if (type == 'polygon') {
          path.close();
        }
        return path;
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
            .map(double.parse)
            .toList();
        if (cleanValues.length == 6) {
          return Matrix4(
            cleanValues[0], cleanValues[1], 0, 0,
            cleanValues[2], cleanValues[3], 0, 0,
            0, 0, 1, 0,
            cleanValues[4], cleanValues[5], 0, 1,
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
            .map(double.parse)
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
            .map(double.parse)
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
            .map(double.parse)
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
}
