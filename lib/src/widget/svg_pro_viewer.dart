import 'package:flutter/material.dart';

import '../models/svg_part.dart';
import '../painter/svg_canvas_painter.dart';
import '../parser/svg_parser_engine.dart';
import '../transformer/svg_viewport_transformation.dart';

class SvgProViewer extends StatefulWidget {
  final String rawSvg;
  final String? externalCss;
  final Function(SvgPart component)? onPartSelected;
  final Color? selectionHighlightColor;

  const SvgProViewer({
    super.key,
    required this.rawSvg,
    this.externalCss,
    this.onPartSelected,
    this.selectionHighlightColor,
  });

  @override
  State<SvgProViewer> createState() => _SvgProViewerState();
}

class _SvgProViewerState extends State<SvgProViewer> {
  late final SvgParserEngine _parserEngine;
  late final List<SvgPart> _parsedComponents;
  String? _selectedComponentId;

  @override
  void initState() {
    super.initState();
    _parserEngine = SvgParserEngine();
    _parsedComponents = _parserEngine.parse(widget.rawSvg, externalCss: widget.externalCss);
  }

  void _processTapEvent(Offset globalOffset, BoxConstraints limits) {
    final renderBox = context.findRenderObject() as RenderBox;
    final localLayoutOffset = renderBox.globalToLocal(globalOffset);

    final viewportTransformer = SvgViewportTransformation(
      viewBox: _parserEngine.viewBox,
      canvasLayoutSize: Size(limits.maxWidth, limits.maxHeight),
    );

    final vectorSpaceOffset = viewportTransformer.screenToVectorSpace(localLayoutOffset);

    for (var component in _parsedComponents.reversed) {
      for (var drawable in component.drawablePaths) {
        if (drawable.path.contains(vectorSpaceOffset)) {
          setState(() {
            _selectedComponentId = component.id;
          });
          if (widget.onPartSelected != null) {
            widget.onPartSelected!(component);
          }
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewBox = _parserEngine.viewBox;
    final aspectRatio = (viewBox.width > 0 && viewBox.height > 0)
        ? viewBox.width / viewBox.height
        : 1.0;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (details) => _processTapEvent(details.globalPosition, constraints),
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: SvgCanvasPainter(
                parts: _parsedComponents,
                selectedId: _selectedComponentId,
                viewBox: _parserEngine.viewBox,
                highlightColor: widget.selectionHighlightColor ?? const Color(0x802196F3),
              ),
            ),
          );
        },
      ),
    );
  }
}
