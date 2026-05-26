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
      title: 'SVG Pro Demo',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const SvgDemoPage(),
    );
  }
}

class SvgDemoPage extends StatelessWidget {
  const SvgDemoPage({super.key});

  Future<Map<String, String>> loadAssets() async {
    final svgData = await rootBundle.loadString('assets/car-front.svg');
    final cssData = await rootBundle.loadString('assets/cardiagram.css');
    return {'svg': svgData, 'css': cssData};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_svg_pro Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<Map<String, String>>(
                future: loadAssets(),
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
                    selectionHighlightColor: const Color(0x804CAF50),
                    onPartSelected: (component) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Selected: ${component.name}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap on car parts to select them',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
