import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_drawing_toddler_paint/drawing/drawing_controller.dart';
import 'package:kids_drawing_toddler_paint/export/drawing_export_service.dart';

void main() {
  group('Drawing export encoders', () {
    late DrawingController controller;

    setUp(() {
      controller = DrawingController();
      controller.setCanvasSize(const Size(160, 120));
      controller.beginStroke(const Offset(12, 20), pressure: 0.4);
      controller.appendActivePoint(const Offset(48, 55), pressure: 0.9);
      controller.finishStroke();
      controller.beginStroke(const Offset(60, 64));
      controller.appendActivePoint(const Offset(100, 80));
      controller.finishStroke();
    });

    tearDown(() => controller.dispose());

    test('SVG output contains vector paths and layer opacity', () {
      final svg = DrawingExportService.toSvg(
        controller,
        width: controller.canvasSize.width,
        height: controller.canvasSize.height,
      );
      expect(svg, startsWith('<?xml'));
      expect(svg, contains('<svg'));
      expect(svg, contains('<polyline'));
      expect(svg, contains('layer-1'));
      expect(svg, contains('opacity="1.000"'));
    });

    test('timelapse output is a multi-frame GIF', () {
      final gif = DrawingExportService.encodeTimelapseGif(
        controller,
        width: 96,
        height: 96,
        maxFrames: 2,
      );
      expect(String.fromCharCodes(gif.take(3)), 'GIF');
      expect(gif.length, greaterThan(16));
      // A GIF with multiple frames contains more than one image descriptor.
      expect(gif.where((byte) => byte == 0x2C).length, greaterThanOrEqualTo(2));
    });

    test('timelapse supports a single-stroke artwork as an animation', () {
      controller.clearCanvas();
      controller.beginStroke(const Offset(12, 20));
      controller.appendActivePoint(const Offset(80, 60));
      controller.finishStroke();
      final gif = DrawingExportService.encodeTimelapseGif(
        controller,
        width: 96,
        height: 96,
        maxFrames: 2,
      );
      expect(gif.where((byte) => byte == 0x2C).length, greaterThanOrEqualTo(2));
    });
  });
}
