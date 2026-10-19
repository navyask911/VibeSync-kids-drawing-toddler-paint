import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_controller.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_models.dart';
import 'package:kids_drawing_toddler_paint/drawing/flood_fill_engine.dart';
import 'package:kids_drawing_toddler_paint/l10n/app_localizations.dart';

void main() {
  group('DrawingController', () {
    late DrawingController controller;
    setUp(() => controller = DrawingController(persistenceEnabled: false));
    tearDown(() => controller.dispose());

    test('each stroke preserves its original color and brush style', () {
      controller.selectBrushColor(Colors.red);
      controller.selectBrushStyle(StrokeStyle.neon);
      controller.beginStroke(const Offset(1, 1));
      controller.extendStroke(const Offset(8, 9));
      controller.endStroke();

      controller.selectBrushColor(Colors.blue);
      controller.selectBrushStyle(StrokeStyle.rainbow);
      controller.beginStroke(const Offset(3, 4));
      controller.extendStroke(const Offset(9, 14));
      controller.endStroke();

      expect(controller.strokes, hasLength(2));
      expect(controller.strokes[0].color, Colors.red);
      expect(controller.strokes[0].style, StrokeStyle.neon);
      expect(controller.strokes[1].color, Colors.blue);
      expect(controller.strokes[1].style, StrokeStyle.rainbow);
    });

    test('undo and redo restore committed strokes', () {
      controller.beginStroke(const Offset(1, 1));
      controller.extendStroke(const Offset(10, 10));
      controller.endStroke();
      controller.undo();
      expect(controller.strokes, isEmpty);
      expect(controller.canRedo, isTrue);
      controller.redo();
      expect(controller.strokes, hasLength(1));
    });

    test('background changes are undoable and redoable', () {
      controller.setBackgroundColor(Colors.pink);
      expect(controller.backgroundColor, Colors.pink);
      controller.undo();
      expect(controller.backgroundColor, Colors.white);
      controller.redo();
      expect(controller.backgroundColor, Colors.pink);
    });

    test('a new edit clears redo history', () {
      controller.beginStroke(const Offset(1, 1));
      controller.extendStroke(const Offset(5, 5));
      controller.endStroke();
      controller.undo();
      controller.placeSelectedStamp(const Offset(30, 30));
      expect(controller.canRedo, isFalse);
    });

    test('stamps are sorted by layer and then stable insertion order', () {
      CanvasStamp make(String id, LayerCategory layer, int order) => CanvasStamp(
        id: id, kind: StampKind.flower, position: Offset.zero, scale: 1,
        rotationAngle: 0, fillColor: Colors.pink, strokeColor: Colors.brown,
        layerCategory: layer, order: order,
      );
      final sorted = sortStampsByLayer([
        make('second', LayerCategory.foregroundFlora, 2),
        make('first', LayerCategory.foregroundFlora, 1),
        make('pond', LayerCategory.sceneryPond, 9),
      ]);
      expect(sorted.map((item) => item.id), ['pond', 'first', 'second']);
    });

    test('stroke model safely round-trips JSON data', () {
      final source = AdvancedStroke(
        points: const [Offset(1, 2), Offset(3, 4)],
        style: StrokeStyle.neon, color: Colors.purple, width: 8,
      );
      final restored = AdvancedStroke.fromJson(source.toJson());
      expect(restored.points, source.points);
      expect(restored.style, source.style);
      expect(restored.color.value, source.color.value);
      expect(restored.width, source.width);
    });
  });

  group('Flood fill engine', () {
    test('fills only the four-connected region and returns a transparent overlay', () async {
      const width = 5;
      const height = 5;
      final rgba = Uint8List(width * height * 4);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final o = (y * width + x) * 4;
          final wall = x == 0 || x == 4 || y == 0 || y == 4;
          rgba[o] = wall ? 0 : 255;
          rgba[o + 1] = 0;
          rgba[o + 2] = wall ? 0 : 255;
          rgba[o + 3] = 255;
        }
      }
      final result = await floodFillRgba(
        sourceRgba: rgba, width: width, height: height,
        seedX: 2, seedY: 2, fillRgba: const [255, 0, 0, 255],
        maxPixels: 100, maxRegionPixels: 20,
      );
      expect(result.exceededRegionLimit, isFalse);
      expect(result.filledPixels, 9);
      expect(result.overlayRgba.length, rgba.length);
      expect(result.overlayRgba[(2 * width + 2) * 4], 255);
      expect(result.overlayRgba[3], 0);
    });

    test('rejects invalid seed and stops on an excessively large region', () async {
      final rgba = Uint8List(20 * 20 * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 20; rgba[i + 1] = 20; rgba[i + 2] = 20; rgba[i + 3] = 255;
      }
      await expectLater(
        floodFillRgba(
          sourceRgba: rgba, width: 20, height: 20,
          seedX: -1, seedY: 0, fillRgba: const [0, 0, 255, 255],
        ),
        throwsRangeError,
      );
      final large = await floodFillRgba(
        sourceRgba: rgba, width: 20, height: 20,
        seedX: 10, seedY: 10, fillRgba: const [0, 0, 255, 255],
        maxPixels: 400, maxRegionPixels: 100,
      );
      expect(large.exceededRegionLimit, isTrue);
      expect(large.overlayRgba, isEmpty);
    });
  });

  test('localization supports six languages and English fallback', () {
    expect(AppLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll(['en', 'es', 'hi', 'zh', 'de', 'fr']));
    const unknown = AppLocalizations(Locale('xx'));
    expect(unknown.translate('undo'), 'Undo');
    expect(unknown.translate('unknown_key'), 'unknown_key');
  });
}