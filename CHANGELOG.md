## 1.0.0-beta

* Initial beta release of `flutter_svg_pro`.
* Added `SvgProViewer` widget supporting interactive hit-testing, single/multi-selection modes, and custom selection highlight overlays.
* Implemented `SvgParserEngine` with hybrid auto-threshold isolate parsing: small SVGs (<50KB) parse instantly on the main thread, while large SVGs automatically execute inside a background isolate.
* Implemented zero-copy isolate transfer protocol utilizing flat Dart primitive maps to eliminate serialization overhead and memory spikes.
* Implemented `SvgStyleRegistry` with full support for CSS selectors, inline style attributes, and embedded/external stylesheets.
* Resolved viewport scaling and coordinate transformations based on SVG `viewBox` properties.
