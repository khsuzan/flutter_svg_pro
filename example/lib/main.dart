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
      title: 'SVG Pro Diagnostics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF0284C7),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x1F0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const SvgDemoPage(),
    );
  }
}

class CarSideItem {
  final String name;
  final String path;
  final IconData icon;
  final String description;

  const CarSideItem({
    required this.name,
    required this.path,
    required this.icon,
    required this.description,
  });
}

class SvgDemoPage extends StatefulWidget {
  const SvgDemoPage({super.key});

  @override
  State<SvgDemoPage> createState() => _SvgDemoPageState();
}

class _SvgDemoPageState extends State<SvgDemoPage> {
  SvgSelectionMode _mode = SvgSelectionMode.multiple;
  String _selectedSidePath = 'assets/car-front.svg';
  
  // Selections tracked per side
  final Map<String, Set<String>> _selectionsPerSide = {
    'assets/car-front.svg': {},
    'assets/left_side.svg': {},
    'assets/car-top.svg': {},
    'assets/right_side.svg': {},
    'assets/car-back.svg': {},
  };

  // Human-readable names of selections tracked per side
  final Map<String, List<String>> _selectionNamesPerSide = {
    'assets/car-front.svg': [],
    'assets/left_side.svg': [],
    'assets/car-top.svg': [],
    'assets/right_side.svg': [],
    'assets/car-back.svg': [],
  };

  Future<Map<String, String>>? _assetsFuture;

  final List<CarSideItem> _carSides = const [
    CarSideItem(
      name: 'Front View',
      path: 'assets/car-front.svg',
      icon: Icons.arrow_upward_rounded,
      description: 'Bonnet, bumper, headlights',
    ),
    CarSideItem(
      name: 'Left Side',
      path: 'assets/left_side.svg',
      icon: Icons.arrow_back_rounded,
      description: 'Doors, fenders, wheels',
    ),
    CarSideItem(
      name: 'Top View',
      path: 'assets/car-top.svg',
      icon: Icons.grid_view_rounded,
      description: 'Roof, hood, trunk',
    ),
    CarSideItem(
      name: 'Right Side',
      path: 'assets/right_side.svg',
      icon: Icons.arrow_forward_rounded,
      description: 'Doors, fenders, wheels',
    ),
    CarSideItem(
      name: 'Back View',
      path: 'assets/car-back.svg',
      icon: Icons.arrow_downward_rounded,
      description: 'Boot, bumper, exhaust',
    ),
  ];

  Future<Map<String, String>> _loadAssets(String svgPath) async {
    final svgData = await rootBundle.loadString(svgPath);
    final cssData = await rootBundle.loadString('assets/cardiagram.css');
    return {'svg': svgData, 'css': cssData};
  }

  @override
  void initState() {
    super.initState();
    _assetsFuture = _loadAssets(_selectedSidePath);
  }

  void _onSideChanged(String path) {
    if (_selectedSidePath == path) return;
    setState(() {
      _selectedSidePath = path;
      _assetsFuture = _loadAssets(path);
    });
  }

  void _clearCurrentSide() {
    setState(() {
      _selectionsPerSide[_selectedSidePath] = {};
      _selectionNamesPerSide[_selectedSidePath] = [];
    });
  }

  void _clearAllSides() {
    setState(() {
      for (var path in _selectionsPerSide.keys) {
        _selectionsPerSide[path] = {};
        _selectionNamesPerSide[path] = [];
      }
    });
  }

  int _getTotalSelectedCount() {
    return _selectionsPerSide.values.fold(0, (sum, set) => sum + set.length);
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 10),
              Text('Diagnostic Report'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _carSides.map((side) {
                final names = _selectionNamesPerSide[side.path] ?? [];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(side.icon, size: 18, color: const Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Text(
                            side.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${names.length} selected',
                            style: TextStyle(
                              color: names.isNotEmpty ? const Color(0xFF10B981) : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (names.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 26, top: 4),
                          child: Wrap(
                            spacing: 6,
                            children: names.map((name) {
                              return Chip(
                                label: Text(name, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: const Color(0xFFF1F5F9),
                              );
                            }).toList(),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(left: 26, top: 2),
                          child: Text(
                            'No defects or parts marked.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      const Divider(height: 16),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Color(0xFF0284C7),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SVG PRO DIAGNOSTICS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Select vehicle areas to log defects',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          // Selections Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x1A0284C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0284C7), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Text(
                      '${_getTotalSelectedCount()} MARKED',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sidebar Menu
        Container(
          width: 320,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Expanded(child: _buildSideMenu(isVertical: true)),
              _buildConfigPanel(),
            ],
          ),
        ),
        // Main SVG Area
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(child: _buildViewerCard()),
                const SizedBox(height: 16),
                _buildSelectionsSummary(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Horizontal Menu at top
          SizedBox(
            height: 90,
            child: _buildSideMenu(isVertical: false),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Main SVG Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildViewerCard(),
            ),
          ),
          // Configuration and Selections Summary at bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Mode: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(child: _buildSelectionModeToggle()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildSelectionsSummary(),
          ),
        ],
      ),
    );
  }

  Widget _buildSideMenu({required bool isVertical}) {
    if (isVertical) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _carSides.length,
        itemBuilder: (context, index) {
          final side = _carSides[index];
          final isSelected = _selectedSidePath == side.path;
          final count = _selectionsPerSide[side.path]?.length ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: isSelected ? const Color(0x1A0284C7) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => _onSideChanged(side.path),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(side.icon, color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade600, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              side.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              side.description,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          child: Center(
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _carSides.length,
        itemBuilder: (context, index) {
          final side = _carSides[index];
          final isSelected = _selectedSidePath == side.path;
          final count = _selectionsPerSide[side.path]?.length ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 130,
              decoration: BoxDecoration(
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0x1A0284C7),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Material(
                color: isSelected ? const Color(0x1A0284C7) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _onSideChanged(side.path),
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(side.icon, color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade600, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                side.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Center(
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildConfigPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SELECTION SETTINGS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          _buildSelectionModeToggle(),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _showReportDialog,
            icon: const Icon(Icons.assignment_rounded, size: 18),
            label: const Text('Export Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _clearAllSides,
            icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
            label: const Text('Clear All Views', style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionModeToggle() {
    return SegmentedButton<SvgSelectionMode>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment(
          value: SvgSelectionMode.single,
          icon: Icon(Icons.touch_app_rounded, size: 16),
          label: Text('Single'),
        ),
        ButtonSegment(
          value: SvgSelectionMode.multiple,
          icon: Icon(Icons.select_all_rounded, size: 16),
          label: Text('Multiple'),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (set) {
        setState(() {
          _mode = set.first;
          // Clear current side on mode switch to avoid mismatching selection count
          _clearCurrentSide();
        });
      },
    );
  }

  Widget _buildViewerCard() {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<Map<String, String>>(
                future: _assetsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF0284C7)),
                          SizedBox(height: 12),
                          Text('Loading Vector Graphics...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                          const SizedBox(height: 12),
                          Text('Error loading asset: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SvgProViewer(
                        key: ValueKey(_selectedSidePath), // Enforce fresh state when switching assets
                        rawSvg: data['svg']!,
                        externalCss: data['css'],
                        selectionMode: _mode,
                        selectedPartIds: _selectionsPerSide[_selectedSidePath],
                        selectionHighlightColor: const Color(0x4010B981), // clean translucent green
                        colorOverrides: const {
                          'st0': Color(0xFFE2E8F0), // premium light slate grey
                        },
                        onPartSelected: (part) {
                          debugPrint('Selected Part: ${part.name} (id: ${part.id})');
                        },
                        onSelectionChanged: (parts) {
                          setState(() {
                            _selectionsPerSide[_selectedSidePath] = parts.map((p) => p.id).toSet();
                            _selectionNamesPerSide[_selectedSidePath] = parts.map((p) => p.name).toList();
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            // Floating View Title
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xD9FFFFFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _carSides.firstWhere((s) => s.path == _selectedSidePath).icon,
                      size: 14,
                      color: const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _carSides.firstWhere((s) => s.path == _selectedSidePath).name.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                    ),
                  ],
                ),
              ),
            ),
            // Floating Help text
            Positioned(
              bottom: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x99FFFFFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tap components to select/deselect',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionsSummary() {
    final currentNames = _selectionNamesPerSide[_selectedSidePath] ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'SELECTION LOG',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                    ),
                    const Spacer(),
                    if (currentNames.isNotEmpty)
                      GestureDetector(
                        onTap: _clearCurrentSide,
                        child: const Row(
                          children: [
                            Icon(Icons.clear_rounded, size: 14, color: Colors.redAccent),
                            SizedBox(width: 4),
                            Text('Clear view', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (currentNames.isNotEmpty)
                  SizedBox(
                    height: 28,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: currentNames.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Chip(
                            label: Text(
                              currentNames[index],
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                            ),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: const BorderSide(color: Color(0xFF0284C7), width: 0.5),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'No parts marked on this side view.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          // Clean Layout action on mobile/narrow view
          if (MediaQuery.of(context).size.width <= 900) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _showReportDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              child: const Icon(Icons.assignment_rounded),
            ),
          ]
        ],
      ),
    );
  }
}
