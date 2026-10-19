import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum StrokeStyle { solid, neon, rainbow }

enum LayerCategory {
  background,
  sceneryPond,
  architectureHouse,
  foregroundFlora,
  activeScribble,
}

enum ActiveTool { brush, paintBucket, stamp }

enum StampKind { house, flower, pond, fish }

enum ColoringPage { freeDraw, puppy, sunshine, rocket, unicorn }

class AdvancedStroke {
  AdvancedStroke({
    required Iterable<Offset> points,
    required this.style,
    required this.color,
    required double width,
    this.order = 0,
  })  : points = List<Offset>.unmodifiable(points),
        width = width.clamp(1.0, 48.0).toDouble();

  final List<Offset> points;
  final StrokeStyle style;
  final Color color;
  final double width;
  final int order;

  LayerCategory get layerCategory => LayerCategory.activeScribble;

  Path get path {
    final result = Path();
    if (points.isEmpty) return result;
    result.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      result.lineTo(point.dx, point.dy);
    }
    return result;
  }
}

class CanvasStamp {
  const CanvasStamp({
    required this.kind,
    required this.position,
    required this.scale,
    required this.rotationAngle,
    required this.fillColor,
    required this.strokeColor,
    required this.layerCategory,
    required this.order,
  });

  final StampKind kind;
  final Offset position;
  final double scale;
  final double rotationAngle;
  final Color fillColor;
  final Color strokeColor;
  final LayerCategory layerCategory;
  final int order;
}

class CanvasFill {
  const CanvasFill({
    required this.image,
    required this.logicalSize,
  });

  final ui.Image image;
  final Size logicalSize;
}
