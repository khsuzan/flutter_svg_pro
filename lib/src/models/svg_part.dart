import 'drawable_path.dart';

/// Represents an interactive, selectable logical part or region in the SVG.
/// 
/// Consists of one or more [DrawablePath] segments that share a unique identifier.
class SvgPart {
  /// The unique identifier of this part, usually derived from the element's `id` attribute.
  final String id;

  /// The human-readable name of this part, often derived from parent group tooltips or names.
  final String name;

  /// The list of [DrawablePath] vector segments that compose this part.
  final List<DrawablePath> drawablePaths;

  /// Optional metadata extracted from attributes of this SVG part.
  final Map<String, String> metadata;

  /// Whether this part is interactive and selectable.
  final bool isSelectable;

  /// Creates a new [SvgPart] with the given [id], [name], [drawablePaths], [isSelectable], and optional [metadata].
  SvgPart({
    required this.id,
    required this.name,
    required this.drawablePaths,
    this.metadata = const {},
    this.isSelectable = true,
  });
}
