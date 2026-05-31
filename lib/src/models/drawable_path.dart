import 'dart:ui';

import 'svg_style.dart';

/// Represents a parsed vector path segment in an SVG, along with its resolved style.
class DrawablePath {
  /// The graphic [Path] representing this segment.
  final Path path;

  /// The resolved styling (fill and stroke) applied to this path segment.
  final SvgStyle style;

  /// Creates a new [DrawablePath] with the given [path] and [style].
  DrawablePath({
    required this.path,
    required this.style,
  });
}
