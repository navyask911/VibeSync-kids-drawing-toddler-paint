import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_controller.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Parent-selected artwork backups', () {
    late Directory directory;
    late DrawingController controller;
    late DrawingPersistence persistence;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('vibesync-backup-test-');
      controller = DrawingController();
      persistence = DrawingPersistence(documentsDirectory: () async => directory);
    });

    tearDown(() async {
      controller.dispose();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('backup round-trip preserves strokes and canvas preferences', () async {
      controller.setBrushColor(Colors.purple);
      final layerId = controller.addLayer(name: 'Pressure ink')!;
      controller.beginStroke(const Offset(10, 12), pressure: 0.25);
      controller.appendActivePoint(const Offset(40, 52), pressure: 0.8);
      controller.finishStroke();
      controller.setBackgroundColor(Colors.lightBlue);

      final bytes = await persistence.exportBackup(controller);
      expect(bytes, isNotEmpty);

      controller.clearCanvas();
      controller.removeLayer(layerId);
      controller.setBackgroundColor(Colors.white);
      final restored = await persistence.restoreBackup(bytes, controller);

      expect(restored, isTrue);
      expect(controller.strokes, hasLength(1));
      expect(controller.strokes.single.points.last, const Offset(40, 52));
      expect(controller.strokes.single.color, const Color(0xFF9C27B0));
      expect(controller.strokes.single.layerId, layerId);
      expect(controller.strokes.single.pressureSamples, <double>[0.25, 0.8]);
      expect(controller.layers.map((layer) => layer.name), contains('Pressure ink'));
      expect(controller.backgroundColor, const Color(0xFF03A9F4));
    });

    test('local autosave uses the same portable backup snapshot', () async {
      controller.beginStroke(const Offset(1, 2));
      controller.appendActivePoint(const Offset(3, 4));
      controller.finishStroke();
      await persistence.save(controller);
      controller.clearCanvas();

      expect(await persistence.restore(controller), isTrue);
      expect(controller.strokes, hasLength(1));
    });

    test('invalid or oversized backups are rejected before changing the scene', () async {
      final initialColor = controller.backgroundColor;
      expect(
        () => persistence.restoreBackup(
          Uint8List.fromList('{"version":99}'.codeUnits),
          controller,
        ),
        throwsFormatException,
      );
      expect(controller.backgroundColor, initialColor);
      expect(
        () => persistence.restoreBackup(Uint8List(20 * 1024 * 1024 + 1), controller),
        throwsFormatException,
      );
    });
  });
}
