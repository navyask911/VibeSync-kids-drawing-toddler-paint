import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_controller.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_models.dart';

void main() {
  group('Pro Artist drawing controller', () {
    late DrawingController controller;

    setUp(() {
      controller = DrawingController();
      controller.setCanvasSize(const Size(120, 120));
    });

    tearDown(() => controller.dispose());

    test('layers support selection, opacity, visibility and merge down', () {
      final layerId = controller.addLayer(name: 'Highlights');
      expect(layerId, isNotNull);
      expect(controller.layers, hasLength(2));
      expect(controller.selectLayer(layerId!), isTrue);
      expect(controller.activeLayerId, layerId);
      expect(controller.setLayerOpacity(layerId, 0.35), isTrue);
      expect(controller.layers.last.opacity, closeTo(0.35, 0.001));
      expect(controller.setLayerVisibility(layerId, false), isTrue);
      expect(controller.layers.last.visible, isFalse);

      controller.beginStroke(const Offset(10, 10));
      controller.appendActivePoint(const Offset(25, 28));
      controller.finishStroke();
      expect(controller.strokes.single.layerId, layerId);

      expect(controller.mergeLayerDown(layerId), isTrue);
      expect(controller.layers, hasLength(1));
      expect(controller.strokes.single.layerId, controller.layers.single.id);
    });

    test('stamps are assigned to the active layer', () {
      final layerId = controller.addLayer(name: 'Sticker layer')!;
      controller.setActiveTool(ActiveTool.stamp);
      controller.setSelectedStamp(StampKind.house);
      controller.addStamp(const Offset(44, 60));

      expect(controller.stamps, hasLength(1));
      expect(controller.stamps.single.layerId, layerId);
    });

    test('a layer can be removed without removing the base layer', () {
      final layerId = controller.addLayer(name: 'Discard');
      expect(controller.removeLayer(layerId!), isTrue);
      expect(controller.layers, hasLength(1));
      expect(controller.removeLayer(controller.layers.single.id), isFalse);
    });

    test('radial symmetry commits a single undoable 4-way stroke', () {
      controller.setSymmetryMode(SymmetryMode.radial4);
      controller.beginStroke(const Offset(60, 20), pressure: 0.25);
      controller.appendActivePoint(const Offset(72, 30), pressure: 0.85);
      controller.finishStroke();

      expect(controller.strokes, hasLength(4));
      expect(controller.strokes.first.pressureSamples, <double>[0.25, 0.85]);
      expect(controller.undo(), isTrue);
      expect(controller.strokes, isEmpty);
      expect(controller.canRedo, isTrue);
    });

    test('mirror symmetry creates a reflected stroke pair', () {
      controller.setSymmetryMode(SymmetryMode.mirrorHorizontal);
      controller.beginStroke(const Offset(20, 20));
      controller.appendActivePoint(const Offset(30, 30));
      controller.finishStroke();

      expect(controller.strokes, hasLength(2));
      expect(controller.strokes.last.points.first.dx, closeTo(100, 0.001));
    });
  });
}
