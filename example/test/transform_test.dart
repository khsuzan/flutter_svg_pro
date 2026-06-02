// ignore_for_file: avoid_print

import 'dart:math';
import 'package:vector_math/vector_math_64.dart';

void main() {
  final cx = 249.4635124206543;
  final cy = 540.0050048828125;
  final a = 90.0;
  
  final m = Matrix4.identity();
  m.multiply(Matrix4.translationValues(cx, cy, 0.0));
  m.rotateZ(a * pi / 180.0);
  m.multiply(Matrix4.translationValues(-cx, -cy, 0.0));
  
  print(m);
  
  final vec = Vector3(277.08, 539.54, 0.0);
  m.transform3(vec);
  print(vec);
}
