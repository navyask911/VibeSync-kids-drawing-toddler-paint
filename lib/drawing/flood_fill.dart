import 'dart:typed_data';

/// Produces a transparent RGBA overlay for a bounded four-neighbour flood fill.
/// The source pixel buffer is never mutated. An empty result means invalid input
/// or that the matching region exceeded the configured pixel budget.
Uint8List floodFillRgba(Map<String, Object?> input) {
  final pixels = input['pixels'];
  final width = input['width'];
  final height = input['height'];
  final seedX = input['seedX'];
  final seedY = input['seedY'];
  final targetR = input['red'];
  final targetG = input['green'];
  final targetB = input['blue'];
  final targetA = input['alpha'];
  final tolerance = input['tolerance'];
  final maxPixels = input['maxPixels'];

  if (pixels is! Uint8List ||
      width is! int ||
      height is! int ||
      seedX is! int ||
      seedY is! int ||
      targetR is! int ||
      targetG is! int ||
      targetB is! int ||
      targetA is! int ||
      tolerance is! int ||
      maxPixels is! int ||
      width <= 0 ||
      height <= 0 ||
      width > 1000000 ||
      height > 1000000 ||
      width * height > 1000000 ||
      pixels.lengthInBytes != width * height * 4 ||
      seedX < 0 ||
      seedY < 0 ||
      seedX >= width ||
      seedY >= height ||
      tolerance < 0 ||
      tolerance > 255 ||
      maxPixels <= 0) {
    return Uint8List(0);
  }

  final pixelCount = width * height;
  final overlay = Uint8List(pixelCount * 4);
  final visited = Uint8List(pixelCount);
  final queue = Int32List(pixelCount);

  final seedIndex = seedY * width + seedX;
  final seedOffset = seedIndex * 4;
  final seedR = pixels[seedOffset];
  final seedG = pixels[seedOffset + 1];
  final seedB = pixels[seedOffset + 2];

  bool matches(int index) {
    final offset = index * 4;
    return (pixels[offset] - seedR).abs() <= tolerance &&
        (pixels[offset + 1] - seedG).abs() <= tolerance &&
        (pixels[offset + 2] - seedB).abs() <= tolerance &&
        pixels[offset + 3] > 0;
  }

  var head = 0;
  var tail = 0;
  var filled = 0;
  queue[tail++] = seedIndex;
  visited[seedIndex] = 1;

  void tryEnqueue(int index) {
    if (index < 0 || index >= pixelCount || visited[index] != 0) return;
    if (matches(index)) {
      visited[index] = 1;
      queue[tail++] = index;
    }
  }

  while (head < tail) {
    final index = queue[head++];
    final offset = index * 4;
    overlay[offset] = targetR.clamp(0, 255).toInt();
    overlay[offset + 1] = targetG.clamp(0, 255).toInt();
    overlay[offset + 2] = targetB.clamp(0, 255).toInt();
    overlay[offset + 3] = targetA.clamp(0, 255).toInt();
    filled++;
    if (filled > maxPixels) return Uint8List(0);

    final x = index % width;
    final y = index ~/ width;
    if (x > 0) tryEnqueue(index - 1);
    if (x + 1 < width) tryEnqueue(index + 1);
    if (y > 0) tryEnqueue(index - width);
    if (y + 1 < height) tryEnqueue(index + width);
  }

  return overlay;
}
