import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_controller.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_models.dart';

void main() {
  group('DrawingController history', () {
    late DrawingController controller;

    setUp(() => controller = DrawingController());
    tearDown(() => controller.dispose());

    test('a committed stroke keeps its original color when the palette changes', () {
      controller.setBrushColor(Colors.red);
      controller.beginStroke(const Offset(4, 5));
      controller.appendActivePoint(const Offset(14, 15));
      controller.finishStroke();

      controller.setBrushColor(Colors.blue);

      expect(controller.strokes, hasLength(1));
      expect(controller.strokes.single.color, Colors.red);
      expect(controller.strokes.single.points, const [
        Offset(4, 5),
        Offset(14, 15),
      ]);
    });

    test('an active stroke keeps its starting brush configuration', () {
      controller.setBrushColor(Colors.red);
      controller.beginStroke(const Offset(1, 1));
      controller.setBrushColor(Colors.blue);
      controller.finishStroke();

      expect(controller.strokes.single.color, Colors.red);
    });

    test('undo and redo restore stroke geometry', () {
      controller.beginStroke(const Offset(1, 2));
      controller.appendActivePoint(const Offset(10, 20));
      controller.finishStroke();

      expect(controller.undo(), isTrue);
      expect(controller.strokes, isEmpty);
      expect(controller.redo(), isTrue);
      expect(controller.strokes, hasLength(1));
      expect(controller.strokes.single.points.last, const Offset(10, 20));
    });

    test('background changes participate in undo/redo', () {
      const before = Color(0xFFFFFFFF);
      const after = Color(0xFFFFE082);
      controller.setBackgroundColor(after);

      expect(controller.backgroundColor, after);
      controller.undo();
      expect(controller.backgroundColor, before);
      controller.redo();
      expect(controller.backgroundColor, after);
    });

    test('stamps are placed and can be undone', () {
      controller.setActiveTool(ActiveTool.stamp);
      controller.setSelectedStamp(StampKind.house);
      controller.addStamp(const Offset(70, 90));

      expect(controller.stamps, hasLength(1));
      expect(controller.stamps.single.kind, StampKind.house);
      expect(controller.stamps.single.layerCategory, LayerCategory.architectureHouse);
      controller.undo();
      expect(controller.stamps, isEmpty);
    });

    test('a new edit after undo clears redo history', () {
      controller.beginStroke(const Offset(0, 0));
      controller.appendActivePoint(const Offset(1, 1));
      controller.finishStroke();
      controller.undo();
      controller.setBackgroundColor(Colors.yellow);

      expect(controller.canRedo, isFalse);
    });

    test('clear can be undone without losing the previous drawing', () {
      controller.beginStroke(const Offset(2, 2));
      controller.appendActivePoint(const Offset(8, 8));
      controller.finishStroke();
      controller.clearCanvas();

      expect(controller.strokes, isEmpty);
      controller.undo();
      expect(controller.strokes, hasLength(1));
    });
  });
}
