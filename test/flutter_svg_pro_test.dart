import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg_pro/flutter_svg_pro.dart';

void main() {
  group('SvgStyle', () {
    test('creates default transparent style', () {
      final style = SvgStyle();
      expect(style.hasFill, false);
      expect(style.hasStroke, false);
      expect(style.fillPaint, isNull);
      expect(style.strokePaint, isNull);
    });

    test('creates style with fill paint', () {
      final fillPaint = Paint()..color = const Color(0xFFFF0000);
      final style = SvgStyle(fillPaint: fillPaint, hasFill: true);
      expect(style.hasFill, true);
      expect(style.fillPaint?.color, const Color(0xFFFF0000));
    });

    test('creates style with stroke paint', () {
      final strokePaint = Paint()
        ..color = const Color(0xFF00FF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      final style = SvgStyle(strokePaint: strokePaint, hasStroke: true);
      expect(style.hasStroke, true);
      expect(style.strokePaint?.color, const Color(0xFF00FF00));
      expect(style.strokePaint?.strokeWidth, 2.5);
    });
  });

  group('DrawablePath', () {
    test('creates drawable path with path and style', () {
      final path = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      final style = SvgStyle();
      final drawable = DrawablePath(path: path, style: style);
      expect(drawable.path, path);
      expect(drawable.style, style);
    });
  });

  group('SvgPart', () {
    test('creates part with id, name, drawable paths', () {
      final path = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      final drawable = DrawablePath(path: path, style: SvgStyle());
      final part = SvgPart(id: 'test-id', name: 'test-name', drawablePaths: [drawable]);
      expect(part.id, 'test-id');
      expect(part.name, 'test-name');
      expect(part.drawablePaths.length, 1);
      expect(part.metadata, {});
    });

    test('supports metadata', () {
      final part = SvgPart(
        id: 'meta-id',
        name: 'meta-name',
        drawablePaths: [],
        metadata: {'key': 'value'},
      );
      expect(part.metadata['key'], 'value');
    });
  });

  group('SvgStyleRegistry', () {
    late SvgStyleRegistry registry;

    setUp(() {
      registry = SvgStyleRegistry();
    });

    test('parses simple CSS class', () {
      registry.parseAndRegisterCss('.st0 { fill: #FF0000; stroke: #000000; stroke-width: 2; }');
      final style = registry.resolveStyle('st0', {});
      expect(style.hasFill, true);
      expect(style.hasStroke, true);
      expect(style.fillPaint?.color, const Color(0xFFFF0000));
    });

    test('parses hex colors with 3-digit shorthand', () {
      registry.parseAndRegisterCss('.shade { fill: #F00; }');
      final style = registry.resolveStyle('shade', {});
      expect(style.hasFill, true);
      expect(style.fillPaint?.color, const Color(0xFFFF0000));
    });

    test('parses hex colors with 6-digit', () {
      registry.parseAndRegisterCss('.custom { fill: #AABBCC; }');
      final style = registry.resolveStyle('custom', {});
      expect(style.hasFill, true);
      expect(style.fillPaint?.color.value, 0xFFAABBCC);
    });

    test('handles fill none', () {
      registry.parseAndRegisterCss('.st0 { fill: none; stroke: #333; }');
      final style = registry.resolveStyle('st0', {});
      expect(style.hasFill, false);
      expect(style.hasStroke, true);
    });

    test('inline fill overrides CSS class', () {
      registry.parseAndRegisterCss('.st0 { fill: #FF0000; }');
      final style = registry.resolveStyle('st0', {'fill': '#00FF00'});
      expect(style.hasFill, true);
      expect(style.fillPaint?.color, const Color(0xFF00FF00));
    });

    test('inline fill none overrides CSS fill', () {
      registry.parseAndRegisterCss('.st0 { fill: #FF0000; }');
      final style = registry.resolveStyle('st0', {'fill': 'none'});
      expect(style.hasFill, false);
    });

    test('returns empty style for unknown class', () {
      final style = registry.resolveStyle('unknown', {});
      expect(style.hasFill, false);
      expect(style.hasStroke, false);
    });

    test('parses compound CSS selectors', () {
      registry.parseAndRegisterCss('.st0, .st1 { fill: none; stroke: #333; }');
      final style0 = registry.resolveStyle('st0', {});
      final style1 = registry.resolveStyle('st1', {});
      expect(style0.hasFill, false);
      expect(style0.hasStroke, true);
      expect(style1.hasFill, false);
      expect(style1.hasStroke, true);
    });

    test('handles px suffix in stroke-width', () {
      registry.parseAndRegisterCss('.st0 { stroke-width: 3px; }');
      final style = registry.resolveStyle('st0', {});
      expect(style.hasStroke, false);
    });

    test('processes multiple CSS rules', () {
      registry
        ..parseAndRegisterCss('.a { fill: #111; }')
        ..parseAndRegisterCss('.b { fill: #222; stroke: #333; }');
      expect(registry.resolveStyle('a', {}).fillPaint?.color.value, 0xFF111111);
      expect(registry.resolveStyle('b', {}).fillPaint?.color.value, 0xFF222222);
      expect(registry.resolveStyle('b', {}).hasStroke, true);
    });
  });

  group('SvgViewportTransformation', () {
    test('transforms screen to vector space', () {
      final viewBox = const Rect.fromLTWH(0, 0, 100, 100);
      final canvasSize = const Size(200, 200);
      final transformer = SvgViewportTransformation(viewBox: viewBox, canvasLayoutSize: canvasSize);

      final centerInVector = transformer.screenToVectorSpace(const Offset(100, 100));
      expect(centerInVector.dx, closeTo(50, 0.01));
      expect(centerInVector.dy, closeTo(50, 0.01));

      final originInVector = transformer.screenToVectorSpace(const Offset(0, 0));
      expect(originInVector.dx, closeTo(0, 0.01));
      expect(originInVector.dy, closeTo(0, 0.01));
    });

    test('handles non-square aspect ratios', () {
      final viewBox = const Rect.fromLTWH(0, 0, 200, 100);
      final canvasSize = const Size(400, 200);
      final transformer = SvgViewportTransformation(viewBox: viewBox, canvasLayoutSize: canvasSize);

      expect(transformer.totalScale, closeTo(2.0, 0.01));

      final mid = transformer.screenToVectorSpace(const Offset(200, 100));
      expect(mid.dx, closeTo(100, 0.01));
      expect(mid.dy, closeTo(50, 0.01));
    });

    test('canvas larger than viewBox scales down', () {
      final viewBox = const Rect.fromLTWH(0, 0, 1000, 1000);
      final canvasSize = const Size(500, 500);
      final transformer = SvgViewportTransformation(viewBox: viewBox, canvasLayoutSize: canvasSize);

      expect(transformer.totalScale, closeTo(0.5, 0.01));
    });
  });

  group('SvgParserEngine', () {
    late SvgParserEngine engine;

    setUp(() {
      engine = SvgParserEngine();
    });

    test('parses SVG with viewBox', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <rect x="10" y="10" width="50" height="50" fill="#FF0000"/>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(engine.viewBox, const Rect.fromLTWH(0, 0, 100, 100));
      expect(parts.length, 1);
    });

    test('falls back to width/height when no viewBox', () async {
      final svg = '''<svg width="200" height="150">
        <rect x="10" y="10" width="50" height="50"/>
      </svg>''';
      await engine.parseAsync(svg);
      expect(engine.viewBox, const Rect.fromLTWH(0, 0, 200, 150));
    });

    test('parses path elements', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <path d="M10 10 L 50 10 L 50 50 Z" fill="#00FF00"/>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 1);
      expect(parts.first.drawablePaths.length, 1);
    });

    test('parses embedded style elements', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <style>.st0 { fill: #FF0000; }</style>
        <path class="st0" d="M10 10 L 50 10 L 50 50 Z"/>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 1);
      expect(parts.first.drawablePaths.first.style.hasFill, true);
      expect(
        parts.first.drawablePaths.first.style.fillPaint?.color,
        const Color(0xFFFF0000),
      );
    });

    test('handles self-closing XML tags', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <path class="st0" d="M10 10 L 50 10 L 50 50 Z" />
        <circle cx="20" cy="20" r="10" />
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 2);
    });

    test('parses <a> wrapper with tooltip', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <a onmousemove="showTooltip(evt, 'FRONT LEFT WHEEL ARCH')">
          <rect x="10" y="10" width="30" height="30" fill="#FFF"/>
        </a>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 1);
      expect(parts.first.name, 'FRONT LEFT WHEEL ARCH');
    });

    test('parses <g> groups and accumulates IDs', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <g id="wheel-group">
          <rect x="10" y="10" width="30" height="30" fill="#FFF"/>
          <rect x="50" y="10" width="30" height="30" fill="#000"/>
        </g>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 1);
      expect(parts.first.id, 'wheel-group');
      expect(parts.first.drawablePaths.length, 2);
    });

    test('parses circle elements', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <circle cx="50" cy="50" r="40" fill="#00F"/>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 1);
    });

    test('parses ellipse elements', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <ellipse cx="50" cy="50" rx="40" ry="20" fill="#F00"/>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 1);
    });

    test('parses polygon elements', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <polygon points="10,10 50,50 10,50" fill="#0F0"/>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 1);
    });

    test('parses polyline elements', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <polyline points="10,10 50,50 90,10" fill="none" stroke="#000"/>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 1);
    });

    test('parses matrix transform', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <g transform="matrix(1 0 0 1 20 30)">
          <rect x="0" y="0" width="10" height="10" fill="#F00"/>
        </g>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 1);
      expect(parts.first.drawablePaths.length, 1);
    });

    test('parses translate transform', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <rect transform="translate(10, 20)" x="0" y="0" width="10" height="10" fill="#F00"/>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 1);
    });

    test('applies external CSS', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <rect class="ext" x="10" y="10" width="50" height="50"/>
      </svg>''';
      final externalCss = '.ext { fill: #FF8800; stroke: #000; }';
      final parts = await engine.parseAsync(svg, externalCss: externalCss);
      expect(parts.length, 1);
      expect(parts.first.drawablePaths.first.style.hasFill, true);
      expect(
        parts.first.drawablePaths.first.style.fillPaint?.color.value,
        0xFFFF8800,
      );
    });

    test('handles invalid path data gracefully', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <path d="NOT A VALID PATH" />
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts, isEmpty);
    });

    test('assigns auto-generated IDs to unnamed parts', () async {
      final svg = '''<svg viewBox="0 0 100 100">
        <rect x="10" y="10" width="30" height="30" fill="#F00"/>
        <rect x="50" y="10" width="30" height="30" fill="#0F0"/>
      </svg>''';
      final parts = await engine.parseAsync(svg);
      expect(parts.length, 2);
      expect(parts[0].id, 'part_0');
      expect(parts[1].id, 'part_1');
    });
  });

  group('SvgCanvasPainter', () {
    test('paints without error', () {
      final path = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      final fillPaint = Paint()..color = const Color(0xFFFF0000);
      final drawable = DrawablePath(
        path: path,
        style: SvgStyle(fillPaint: fillPaint, hasFill: true),
      );
      final part = SvgPart(id: 'test', name: 'test', drawablePaths: [drawable]);
      final painter = SvgCanvasPainter(
        parts: [part],
        selectedIds: {},
        viewBox: const Rect.fromLTWH(0, 0, 100, 100),
        highlightColor: const Color(0x802196F3),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();

      expect(painter.shouldRepaint(painter), false);
    });

    test('repaints when selectedIds changes', () {
      final painter1 = SvgCanvasPainter(
        parts: [],
        selectedIds: {'a'},
        viewBox: Rect.zero,
        highlightColor: const Color(0x802196F3),
      );
      final painter2 = SvgCanvasPainter(
        parts: [],
        selectedIds: {'b'},
        viewBox: Rect.zero,
        highlightColor: const Color(0x802196F3),
      );
      expect(painter1.shouldRepaint(painter2), true);
    });

    test('does not repaint when nothing changes', () {
      final painter1 = SvgCanvasPainter(
        parts: [],
        selectedIds: {},
        viewBox: Rect.zero,
        highlightColor: const Color(0x802196F3),
      );
      expect(painter1.shouldRepaint(SvgCanvasPainter(
        parts: painter1.parts,
        selectedIds: painter1.selectedIds,
        viewBox: painter1.viewBox,
        highlightColor: painter1.highlightColor,
      )), false);
    });
  });
}
