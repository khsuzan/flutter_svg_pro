import 'package:flutter/material.dart';
import 'package:flutter_svg_pro/flutter_svg_pro.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter SVG Pro Demo',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const SvgDemoPage(),
    );
  }
}

class SvgDemoPage extends StatefulWidget {
  const SvgDemoPage({super.key});

  @override
  State<SvgDemoPage> createState() => _SvgDemoPageState();
}

class _SvgDemoPageState extends State<SvgDemoPage> {
  SvgSelectionMode _mode = SvgSelectionMode.single;
  String _selectionInfo = '';
  Future<Map<String, String>>? _assetsFuture;

  Future<Map<String, String>> _loadAssets() async {
    final svgData = await rootBundle.loadString('assets/car-front.svg');
    final cssData = await rootBundle.loadString('assets/cardiagram.css');
    return {'svg': svgData, 'css': cssData};
  }

  @override
  void initState() {
    super.initState();
    _assetsFuture = _loadAssets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter SVG Pro Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Mode: '),
                SegmentedButton<SvgSelectionMode>(
                  segments: const [
                    ButtonSegment(value: SvgSelectionMode.single, label: Text('Single')),
                    ButtonSegment(value: SvgSelectionMode.multiple, label: Text('Multiple')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (set) {
                    setState(() {
                      _mode = set.first;
                      _selectionInfo = '';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<Map<String, String>>(
                future: _assetsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading assets: ${snapshot.error}'),
                    );
                  }

                  final data = snapshot.data!;
                  return SvgProViewer(
                    rawSvg: data['svg']!,
                    externalCss: data['css'],
                    selectionMode: _mode,
                    selectionHighlightColor: const Color(0x804CAF50),
                    onPartSelected: (component) {
                      debugPrint('Selected: ${component.name}');
                    },
                    onSelectionChanged: (parts) {
                      setState(() {
                        _selectionInfo = parts.map((p) => p.name).join(', ');
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: Text(
                _selectionInfo.isNotEmpty
                    ? 'Selected: $_selectionInfo'
                    : 'Tap on car parts to select them',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
