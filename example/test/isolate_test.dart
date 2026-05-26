import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isolate send test', () async {
    final receivePort = ReceivePort();
    await Isolate.spawn((SendPort sendPort) {
      try {
        final path = Path()..moveTo(0, 0)..lineTo(100, 100);
        sendPort.send(path);
      } catch (e) {
        sendPort.send("Error: $e");
      }
    }, receivePort.sendPort);

    final result = await receivePort.first;
    print("Result: $result");
  });
}
