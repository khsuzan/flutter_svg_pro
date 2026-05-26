import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg_pro/src/parser/svg_parser_engine.dart';
import 'package:xml/xml.dart';

void main() {
  test('benchmark', () async {
    final rawSvgText = File('assets/car-front.svg').readAsStringSync();
    
    final t1 = Stopwatch()..start();
    final document = await compute(XmlDocument.parse, rawSvgText);
    t1.stop();
    print('XmlDocument.parse took: ${t1.elapsedMilliseconds}ms');

    final engine = SvgParserEngine();
    final t2 = Stopwatch()..start();
    await engine.parseAsync(rawSvgText);
    t2.stop();
    print('Full parseAsync took: ${t2.elapsedMilliseconds}ms');
  });
}
