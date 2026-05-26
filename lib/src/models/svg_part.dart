import 'drawable_path.dart';

class SvgPart {
  final String id;
  final String name;
  final List<DrawablePath> drawablePaths;
  final Map<String, String> metadata;

  SvgPart({
    required this.id,
    required this.name,
    required this.drawablePaths,
    this.metadata = const {},
  });
}
