import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_drawing_toddler_paint/drawing/flood_fill.dart';

void main() {
  group('bounded RGBA flood fill', () {
    test('fills only the enclosed center pixel and leaves other pixels transparent', () {
      const width = 3;
      const height = 3;
      final pixels = Uint8List(width * height * 4);
      for (var i = 0; i < width * height; i++) {
        pixels[i * 4] = 255;
        pixels[i * 4 + 1] = 255;
        pixels[i * 4 + 2] = 255;
        pixels[i * 4 + 3] = 255;
      }
      void setPixel(int x, int y, int r, int g, int b) {
        final offset = (y * width + x) * 4;
        pixels[offset] = r;
        pixels[offset + 1] = g;
        pixels[offset + 2] = b;
        pixels[offset + 3] = 255;
      }
      for (var x = 0; x < 3; x++) {
        setPixel(x, 0, 0, 0, 0);
        setPixel(x, 2, 0, 0, 0);
      }
      setPixel(0, 1, 0, 0, 0);
      setPixel(2, 1, 0, 0, 0);

      final result = floodFillRgba({
        'pixels': pixels,
        'width': width,
        'height': height,
        'seedX': 1,
        'seedY': 1,
        'red': 255,
        'green': 0,
        'blue': 0,
        'alpha': 255,
        'tolerance': 0,
        'maxPixels': 10,
      });

      expect(result, hasLength(width * height * 4));
      expect(result[(1 * width + 1) * 4], 255);
      expect(result[(1 * width + 1) * 4 + 1], 0);
      expect(result[(1 * width + 1) * 4 + 3], 255);
      expect(result[(0 * width + 0) * 4 + 3], 0);
    });

    test('invalid seed coordinates are rejected', () {
      final result = floodFillRgba({
        'pixels': Uint8List(4),
        'width': 1,
        'height': 1,
        'seedX': 1,
        'seedY': 0,
        'red': 0,
        'green': 0,
        'blue': 0,
        'alpha': 255,
        'tolerance': 0,
        'maxPixels': 10,
      });
      expect(result, isEmpty);
    });

    test('large matching regions exceeding the configured budget abort safely', () {
      final pixels = Uint8List(4 * 20);
      for (var i = 0; i < 20; i++) {
        pixels[i * 4 + 3] = 255;
      }
      final result = floodFillRgba({
        'pixels': pixels,
        'width': 5,
        'height': 4,
        'seedX': 0,
        'seedY': 0,
        'red': 1,
        'green': 2,
        'blue': 3,
        'alpha': 255,
        'tolerance': 0,
        'maxPixels': 5,
      });
      expect(result, isEmpty);
    });
  });
}
