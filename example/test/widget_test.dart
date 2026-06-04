import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg_pro_example/main.dart';

void main() {
  testWidgets('SVG Pro Diagnostics Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app header shows the title.
    expect(find.text('SVG PRO DIAGNOSTICS'), findsOneWidget);

    // Verify that we display the list of views / sides.
    expect(find.text('FRONT VIEW'), findsOneWidget);
    expect(find.text('Left Side'), findsOneWidget);
    expect(find.text('Top View'), findsOneWidget);
    expect(find.text('Right Side'), findsOneWidget);
    expect(find.text('Back View'), findsOneWidget);

    // Verify that the initial selection count starts at 0.
    expect(find.text('0 MARKED'), findsOneWidget);
  });
}
