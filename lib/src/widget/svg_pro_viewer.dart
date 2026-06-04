import 'package:flutter/material.dart';

import '../models/svg_part.dart';
import '../painter/svg_canvas_painter.dart';
import '../parser/svg_parser_engine.dart';
import '../transformer/svg_viewport_transformation.dart';

/// The interactive selection behavior of [SvgProViewer].
enum SvgSelectionMode {
  /// Allow only a single part to be active/selected at a time.
  single,

  /// Allow multiple parts to be active/selected concurrently.
  multiple,
}

/// A highly-optimized, interactive SVG vector graphics viewer widget for Flutter.
/// 
/// Automatically parses the provided raw SVG XML, extracts selectable [SvgPart] units,
/// handles cascading style registry options, and performs pixel-perfect hit-testing 
/// for single- or multi-part touch selections.
class SvgProViewer extends StatefulWidget {
  /// The raw SVG XML text string.
  final String rawSvg;

  /// Optional external CSS stylesheet content to apply.
  final String? externalCss;

  /// The interactive selection mode configuration (defaults to [SvgSelectionMode.single]).
  final SvgSelectionMode selectionMode;

  /// Callback triggered whenever an individual part is tapped and selected.
  final Function(SvgPart component)? onPartSelected;

  /// Callback triggered with the list of all currently active/selected parts.
  final Function(List<SvgPart> selectedParts)? onSelectionChanged;

  /// The overlay color used to highlight selected parts.
  final Color? selectionHighlightColor;

  /// Optional set of selected part IDs to control selection externally.
  final Set<String>? selectedPartIds;

  /// Creates an interactive [SvgProViewer] with the given parameters.
  const SvgProViewer({
    super.key,
    required this.rawSvg,
    this.externalCss,
    this.selectionMode = SvgSelectionMode.single,
    this.onPartSelected,
    this.onSelectionChanged,
    this.selectionHighlightColor,
    this.selectedPartIds,
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
    if (widget.selectedPartIds != null) {
      _selectedComponentIds.addAll(widget.selectedPartIds!);
    }
    _loadSvg();
  }

  @override
  void didUpdateWidget(SvgProViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawSvg != widget.rawSvg || oldWidget.externalCss != widget.externalCss) {
      _selectedComponentIds.clear();
      if (widget.selectedPartIds != null) {
        _selectedComponentIds.addAll(widget.selectedPartIds!);
      }
      _loadSvg();
    } else if (widget.selectedPartIds != null && oldWidget.selectedPartIds != widget.selectedPartIds) {
      setState(() {
        _selectedComponentIds
          ..clear()
          ..addAll(widget.selectedPartIds!);
      });
    }
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

  void _processTapEvent(Offset globalOffset) {
    if (_parserEngine == null || _parsedComponents == null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final localLayoutOffset = renderBox.globalToLocal(globalOffset);

    final viewportTransformer = SvgViewportTransformation(
      viewBox: _parserEngine!.viewBox,
      canvasLayoutSize: renderBox.size,
    );

    final vectorSpaceOffset = viewportTransformer.screenToVectorSpace(localLayoutOffset);

    for (var component in _parsedComponents!.reversed) {
      if (!component.isSelectable) continue;
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
            onTapUp: (details) => _processTapEvent(details.globalPosition),
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
