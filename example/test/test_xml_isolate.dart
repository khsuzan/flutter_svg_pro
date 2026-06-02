// ignore_for_file: avoid_print

import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('xml isolate send test', () async {
    final receivePort = ReceivePort();
    await Isolate.spawn((SendPort sendPort) {
      try {
        final doc = XmlDocument.parse('<svg><g><path d="M 0 0 L 100 100"/></g></svg>');
        sendPort.send(doc);
        // Wait, Isolate.spawn doesn't crash on compile.
      } catch (e) {
        sendPort.send("Error: $e");
      }
    }, receivePort.sendPort);

    final result = await receivePort.first;
    print("Result string: $result");
  });
}
