import 'dart:isolate';

import 'package:flutter/foundation.dart';

@immutable
class FloodFillResult {
  const FloodFillResult({
    required this.overlayRgba,
    required this.filledPixels,
    required this.exceededRegionLimit,
  });

  /// Same dimensions as the input. Filled pixels contain the selected RGBA
  /// color; all other pixels are transparent, so this bitmap can be layered
  /// underneath the source drawing to preserve crisp outlines.
  final Uint8List overlayRgba;
  final int filledPixels;
  final bool exceededRegionLimit;
}

/// Bounded, non-recursive four-connected flood fill operating on raw RGBA
/// pixels. The source is never mutated. Pixel work is run in a background
/// isolate so even a large canvas does not block Flutter's frame thread.
Future<FloodFillResult> floodFillRgba({
  required Uint8List sourceRgba,
  required int width,
  required int height,
  required int seedX,
  required int seedY,
  required List<int> fillRgba,
  int tolerance = 18,
  int maxPixels = 2000000,
  int maxRegionPixels = 500000,
}) async {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Image dimensions must be positive.');
  }
  if (maxPixels <= 0 || width > maxPixels ~/ height) {
    throw ArgumentError('Image is larger than the configured safe pixel limit.');
  }
  final pixelCount = width * height;
  if (sourceRgba.length != pixelCount * 4) {
    throw ArgumentError('RGBA buffer length does not match the image dimensions.');
  }
  if (seedX < 0 || seedX >= width || seedY < 0 || seedY >= height) {
    throw RangeError('Flood-fill seed must be inside the image.');
  }
  if (fillRgba.length != 4 || fillRgba.any((v) => v < 0 || v > 255)) {
    throw ArgumentError('Fill color must contain four RGBA bytes.');
  }
  if (maxRegionPixels <= 0) {
    throw ArgumentError('Region pixel limit must be positive.');
  }

  final request = _FloodFillRequest(
    sourceRgba: sourceRgba,
    width: width,
    height: height,
    seedX: seedX,
    seedY: seedY,
    fillRgba: List<int>.unmodifiable(fillRgba),
    tolerance: tolerance.clamp(0, 96),
    maxRegionPixels: maxRegionPixels,
  );
  return Isolate.run(() => _floodFillSync(request));
}

class _FloodFillRequest {
  const _FloodFillRequest({
    required this.sourceRgba,
    required this.width,
    required this.height,
    required this.seedX,
    required this.seedY,
    required this.fillRgba,
    required this.tolerance,
    required this.maxRegionPixels,
  });

  final Uint8List sourceRgba;
  final int width;
  final int height;
  final int seedX;
  final int seedY;
  final List<int> fillRgba;
  final int tolerance;
  final int maxRegionPixels;
}

FloodFillResult _floodFillSync(_FloodFillRequest request) {
  final width = request.width;
  final height = request.height;
  final pixelCount = width * height;
  final seedOffset = (request.seedY * width + request.seedX) * 4;
  final source = request.sourceRgba;
  final targetR = source[seedOffset];
  final targetG = source[seedOffset + 1];
  final targetB = source[seedOffset + 2];
  final targetA = source[seedOffset + 3];
  final fill = request.fillRgba;
  if (targetR == fill[0] &&
      targetG == fill[1] &&
      targetB == fill[2] &&
      targetA == fill[3]) {
    return FloodFillResult(
      overlayRgba: Uint8List(0),
      filledPixels: 0,
      exceededRegionLimit: false,
    );
  }

  final visited = Uint8List(pixelCount);
  final queue = Int32List(pixelCount);
  final overlay = Uint8List(pixelCount * 4);
  var readIndex = 0;
  var writeIndex = 0;
  var filled = 0;

  bool matches(int pixelIndex) {
    final offset = pixelIndex * 4;
    final t = request.tolerance;
    return (source[offset] - targetR).abs() <= t &&
        (source[offset + 1] - targetG).abs() <= t &&
        (source[offset + 2] - targetB).abs() <= t &&
        (source[offset + 3] - targetA).abs() <= t;
  }

  void enqueue(int index) {
    if (index < 0 || index >= pixelCount || visited[index] != 0) return;
    visited[index] = 1;
    queue[writeIndex++] = index;
  }

  enqueue(request.seedY * width + request.seedX);
  while (readIndex < writeIndex) {
    final index = queue[readIndex++];
    if (!matches(index)) continue;

    filled++;
    if (filled > request.maxRegionPixels) {
      return FloodFillResult(
        overlayRgba: Uint8List(0),
        filledPixels: filled,
        exceededRegionLimit: true,
      );
    }

    final offset = index * 4;
    overlay[offset] = fill[0];
    overlay[offset + 1] = fill[1];
    overlay[offset + 2] = fill[2];
    overlay[offset + 3] = fill[3];

    final x = index % width;
    if (x > 0) enqueue(index - 1);
    if (x + 1 < width) enqueue(index + 1);
    if (index >= width) enqueue(index - width);
    if (index + width < pixelCount) enqueue(index + width);
  }

  return FloodFillResult(
    overlayRgba: overlay,
    filledPixels: filled,
    exceededRegionLimit: false,
  );
}