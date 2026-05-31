import 'package:flutter/material.dart';

import '../models/svg_part.dart';
import '../painter/svg_canvas_painter.dart';
import '../parser/svg_parser_engine.dart';
import '../transformer/svg_viewport_transformation.dart';

enum SvgSelectionMode { single, multiple }

class SvgProViewer extends StatefulWidget {
  final String rawSvg;
  final String? externalCss;
  final SvgSelectionMode selectionMode;
  final Function(SvgPart component)? onPartSelected;
  final Function(List<SvgPart> selectedParts)? onSelectionChanged;
  final Color? selectionHighlightColor;

  const SvgProViewer({
    super.key,
    required this.rawSvg,
    this.externalCss,
    this.selectionMode = SvgSelectionMode.single,
    this.onPartSelected,
    this.onSelectionChanged,
    this.selectionHighlightColor,
  });

  @override
  State<SvgProViewer> createState() => _SvgProViewerState();
}

class _SvgProViewerState extends State<SvgProViewer> {
  SvgParserEngine? _parserEngine;
  List<SvgPart>? _parsedComponents;
  final Set<String> _selectedComponentIds = {};

  @override
  void initState() {
    super.initState();
    _loadSvg();
  }

  Future<void> _loadSvg() async {
    final engine = SvgParserEngine();
    final components = await engine.parseAsync(widget.rawSvg, externalCss: widget.externalCss);
    if (mounted) {
      setState(() {
        _parserEngine = engine;
        _parsedComponents = components;
      });
    }
  }

  void _processTapEvent(Offset globalOffset, BoxConstraints limits) {
    if (_parserEngine == null || _parsedComponents == null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final localLayoutOffset = renderBox.globalToLocal(globalOffset);

    final viewportTransformer = SvgViewportTransformation(
      viewBox: _parserEngine!.viewBox,
      canvasLayoutSize: Size(limits.maxWidth, limits.maxHeight),
    );

    final vectorSpaceOffset = viewportTransformer.screenToVectorSpace(localLayoutOffset);

    for (var component in _parsedComponents!.reversed) {
      for (var drawable in component.drawablePaths) {
        if (drawable.path.contains(vectorSpaceOffset)) {
          switch (widget.selectionMode) {
            case SvgSelectionMode.single:
              setState(() {
                _selectedComponentIds
                  ..clear()
                  ..add(component.id);
              });
              widget.onPartSelected?.call(component);
              widget.onSelectionChanged?.call([component]);

            case SvgSelectionMode.multiple:
              setState(() {
                if (_selectedComponentIds.contains(component.id)) {
                  _selectedComponentIds.remove(component.id);
                } else {
                  _selectedComponentIds.add(component.id);
                }
              });
              final selectedParts = _parsedComponents!
                  .where((p) => _selectedComponentIds.contains(p.id))
                  .toList();
              widget.onSelectionChanged?.call(selectedParts);
          }
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parserEngine == null || _parsedComponents == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final viewBox = _parserEngine!.viewBox;
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
                parts: _parsedComponents!,
                selectedIds: Set.of(_selectedComponentIds),
                viewBox: _parserEngine!.viewBox,
                highlightColor: widget.selectionHighlightColor ?? const Color(0x802196F3),
              ),
            ),
          );
        },
      ),
    );
  }
}
