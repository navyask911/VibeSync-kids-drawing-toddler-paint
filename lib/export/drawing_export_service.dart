import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';

import '../drawing/drawing_controller.dart';

class DrawingExportService {
  static String toSvg(
    DrawingController controller, {
    required double width,
    required double height,
  }) {
    final safeWidth = width.isFinite && width > 0 ? width : 1.0;
    final safeHeight = height.isFinite && height > 0 ? height : 1.0;
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<svg xmlns="http://www.w3.org/2000/svg" width="$safeWidth" height="$safeHeight" viewBox="0 0 $safeWidth $safeHeight">')
      ..writeln('<rect width="100%" height="100%" fill="${_hex(controller.backgroundColor)}"/>');

    for (final layer in controller.layers) {
      if (!layer.visible || layer.opacity <= 0) continue;
      buffer.writeln('<g id="layer-${layer.id}" opacity="${layer.opacity.toStringAsFixed(3)}">');
      final strokes = controller.strokes
          .where((stroke) => stroke.layerId == layer.id)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final stroke in strokes) {
        if (stroke.points.isEmpty) continue;
        final points = stroke.points
            .map((point) => '${point.dx.toStringAsFixed(2)},${point.dy.toStringAsFixed(2)}')
            .join(' ');
        buffer.writeln(
          '<polyline points="$points" fill="none" stroke="${_hex(stroke.color)}" '
          'stroke-width="${stroke.width.toStringAsFixed(2)}" stroke-linecap="round" stroke-linejoin="round"/>',
        );
      }
      buffer.writeln('</g>');
    }
    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Encodes a bounded progressive GIF of the drawing's recorded stroke order.
  /// The animation contains vector strokes only; no child/device metadata is added.
  static Uint8List encodeTimelapseGif(
    DrawingController controller, {
    int width = 480,
    int height = 480,
    int maxFrames = 24,
  }) {
    final strokes = controller.strokes.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final totalPoints = strokes.fold<int>(
      0,
      (count, stroke) => count + stroke.points.length,
    );
    if (totalPoints == 0) {
      throw StateError('Draw something before exporting a timelapse.');
    }
    if (width < 32 ||
        height < 32 ||
        width > 640 ||
        height > 640 ||
        maxFrames < 2 ||
        maxFrames > 30) {
      throw ArgumentError('GIF output dimensions or frame count are outside safe limits.');
    }

    final sourceWidth =
        controller.canvasSize.width > 0 ? controller.canvasSize.width : 1.0;
    final sourceHeight =
        controller.canvasSize.height > 0 ? controller.canvasSize.height : 1.0;
    final scaleX = (width - 24) / sourceWidth;
    final scaleY = (height - 24) / sourceHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final offsetX = (width - sourceWidth * scale) / 2;
    final offsetY = (height - sourceHeight * scale) / 2;

    final frame = img.Image(width: width, height: height, numChannels: 4);
    img.fill(frame, color: img.ColorRgba8(255, 255, 255, 255));
    final encoder = img.GifEncoder(
      repeat: 0,
      numColors: 96,
      quantizerType: img.QuantizerType.octree,
      dither: img.DitherKernel.none,
    );
    final frameCount = totalPoints < 2
        ? 2
        : (totalPoints < maxFrames ? totalPoints : maxFrames);

    for (var frameIndex = 0; frameIndex < frameCount; frameIndex++) {
      final visiblePointCount =
          ((frameIndex + 1) * totalPoints / frameCount).ceil();
      var remainingPoints = visiblePointCount;

      for (final stroke in strokes) {
        if (remainingPoints <= 0) break;
        if (stroke.points.isEmpty) continue;
        final visibleInStroke = remainingPoints < stroke.points.length
            ? remainingPoints
            : stroke.points.length;
        final color = img.ColorRgba8(
          stroke.color.red,
          stroke.color.green,
          stroke.color.blue,
          stroke.color.alpha,
        );
        final thickness = (stroke.width * scale).round().clamp(1, 24).toInt();

        if (visibleInStroke == 1) {
          final point = stroke.points.first;
          img.drawCircle(
            frame,
            x: (offsetX + point.dx * scale).round(),
            y: (offsetY + point.dy * scale).round(),
            radius: (thickness / 2).ceil(),
            color: color,
          );
        } else {
          for (var pointIndex = 1; pointIndex < visibleInStroke; pointIndex++) {
            final start = stroke.points[pointIndex - 1];
            final end = stroke.points[pointIndex];
            img.drawLine(
              frame,
              x1: (offsetX + start.dx * scale).round(),
              y1: (offsetY + start.dy * scale).round(),
              x2: (offsetX + end.dx * scale).round(),
              y2: (offsetY + end.dy * scale).round(),
              color: color,
              thickness: thickness,
            );
          }
        }
        remainingPoints -= visibleInStroke;
      }
      encoder.addFrame(img.Image.from(frame), duration: 18);
    }

    final bytes = encoder.finish();
    if (bytes == null || bytes.lengthInBytes < 16) {
      throw StateError('The drawing timelapse could not be encoded.');
    }
    return bytes;
  }

  static String _hex(Color color) {
    // ignore: deprecated_member_use
    final rgb = color.value & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
