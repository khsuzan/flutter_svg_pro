# Flutter SVG Pro: A Complete Step-by-Step Guide to Interactive SVG Selection 🚀

Standard packages like `flutter_svg` are perfect for rendering static vector graphics. However, if you need to build interactive visual features—such as selecting specific automotive parts, clicking region maps, or tapping individual elements in complex diagrams to toggle styling and selections—static renderers fall short.

This is where **`flutter_svg_pro`** shines! It is a highly optimized, isolate-powered, high-performance SVG parsing and rendering engine for Flutter. It enables developers to hit-test individual paths and element groups (`<g>`) to trigger custom styling and selections.

In this tutorial, we will walk you through setting up and building a beautiful, fully interactive SVG selection app in Flutter.

---

## 1. Project Setup & Installation 🛠️

Add the package dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_svg_pro: ^1.0.0
```

Then, run the dependency resolver in your terminal:
```bash
flutter pub get
```

---

## 2. Preparing the SVG File (Crucial Step) 📐

For interactive selection to work, individual components in your SVG vector file must have a unique identifier (`id` or `class`). For example, in a car illustration where you want the hood and front door to be individually selectable:

```xml
<svg viewBox="0 0 500 500">
  <!-- Car Hood -->
  <path id="hood" d="M 50 100 L 150 100 ..." fill="#cccccc" />

  <!-- Car Door -->
  <path id="door" d="M 150 100 L 250 100 ..." fill="#aaaaaa" />
</svg>
```
*Note: `flutter_svg_pro` relies on the `id` attributes within your SVG elements to coordinate highlight states and hit-testing callbacks.*

---

## 3. Configuring Assets 📂

Add your SVG file to your assets directory (e.g., `assets/car-front.svg`) and declare it in your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/car-front.svg
```

---

## 4. Step-by-Step Implementation Guide 🚀

To build the interactive screen, we will:
1. Load the SVG resource file dynamically as a string using `rootBundle`.
2. Display a loading indicator while the layout is initialising.
3. Supply the raw SVG string to the `SvgProViewer` widget and track the selected component ids.

### Complete Coding Example (Copy-Paste Ready) 💻

Replace the contents of your `lib/main.dart` with the following implementation:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg_pro/flutter_svg_pro.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interactive SVG Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const InteractiveSvgScreen(),
    );
  }
}

class InteractiveSvgScreen extends StatefulWidget {
  const InteractiveSvgScreen({super.key});

  @override
  State<InteractiveSvgScreen> createState() => _InteractiveSvgScreenState();
}

class _InteractiveSvgScreenState extends State<InteractiveSvgScreen> {
  String? _rawSvgContent;
  String _selectionInfo = "";
  final Set<String> _selectedPartIds = {};

  @override
  void initState() {
    super.initState();
    _loadSvgAsset();
  }

  // Reads the raw SVG asset as a string
  Future<void> _loadSvgAsset() async {
    try {
      final svgString = await rootBundle.loadString('assets/car-front.svg');
      setState(() {
        _rawSvgContent = svgString;
      });
    } catch (e) {
      setState(() {
        _selectionInfo = "Failed to load SVG: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive SVG Part Selection 🚗'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Render SvgProViewer inside a clean Card container
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _rawSvgContent == null
                      ? const Center(child: CircularProgressIndicator())
                      : SvgProViewer(
                          rawSvg: _rawSvgContent!,
                          // Toggle single or multiple selection modes
                          selectionMode: SvgSelectionMode.multiple,
                          // Customise selected highlight overlay colors
                          selectionHighlightColor: Colors.blue.withValues(alpha: 0.5),
                          // Triggers when a component is tapped
                          onPartSelected: (SvgPart part) {
                            debugPrint("Tapped component ID: ${part.id}");
                          },
                          // Triggers on any change to the active selections list
                          onSelectionChanged: (List<SvgPart> selectedParts) {
                            setState(() {
                              _selectedPartIds.clear();
                              _selectedPartIds.addAll(selectedParts.map((p) => p.id));
                              
                              if (selectedParts.isEmpty) {
                                _selectionInfo = "";
                              } else {
                                _selectionInfo = selectedParts.map((p) => p.name).join(', ');
                              }
                            });
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 2. Real-time selection console feedback
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selection Status:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[300],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedPartIds.isNotEmpty
                        ? 'Selected Components: $_selectionInfo'
                        : 'Tap on any car parts above to select them!',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 5. Key Features: Why use Flutter SVG Pro? 🌟

1. **Background Isolate Parser**:
   Parsing massive XML vector coordinates on the UI thread blocks rendering and causes lag. `flutter_svg_pro` utilizes a hybrid isolate setup: small files (<50KB) load instantly on the main thread, while heavy, complex SVGs are automatically offloaded to a background isolate. This guarantees an elegant 120 FPS UI!
2. **Cascading CSS Style Sheets**:
   Supports processing internal CSS stylesheets, inline style attributes, and external CSS rules, merging selectors according to classic CSS inheritance rules.
3. **Pixel-Perfect Hit Testing**:
   Calculates custom scale, translation, and aspect ratio transformations to convert tapped local screen offsets into precise SVG coordinate vectors, assuring precise hit-testing.
4. **Flexible Selection Modes**:
   * `SvgSelectionMode.single` — Allows only a single active selected element.
   * `SvgSelectionMode.multiple` — Perfect for generating checklist items.

---

## 6. Pro Tips & Tricks 💡

* **Clean your SVG vector files**: Always export cleaner SVGs directly from Adobe Illustrator or Figma by purging unnecessary nested `<g>` tags and metadata.
* **Tuning Highlights**: Always supply transparent alpha channel configurations to `selectionHighlightColor` (like `Colors.blue.withValues(alpha: 0.5)`) to keep border lines visible underneath the highlight overlay.

Integrate **`flutter_svg_pro`** inside your Flutter application today to deliver premium, state-of-the-art interactive graphics! 🚀
