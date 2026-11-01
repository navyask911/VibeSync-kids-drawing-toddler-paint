import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum StrokeStyle { solid, neon, rainbow, watercolor, calligraphy, charcoal }

enum SymmetryMode { none, mirrorHorizontal, mirrorVertical, radial4, radial8 }

enum StudioMode { toddler, proArtist }

enum LayerCategory {
  background,
  sceneryPond,
  architectureHouse,
  foregroundFlora,
  activeScribble,
}

enum ActiveTool { brush, paintBucket, stamp, eyedropper }

enum StampKind { house, flower, pond, fish }

enum ColoringPage {
  freeDraw,
  puppy,
  sunshine,
  rocket,
  unicorn,
  dinosaur,
  butterfly,
  castle,
}

extension PremiumDrawingAccess on ColoringPage {
  bool get requiresSubscription => switch (this) {
        ColoringPage.dinosaur ||
        ColoringPage.butterfly ||
        ColoringPage.castle => true,
        _ => false,
      };
}

extension PremiumBrushAccess on StrokeStyle {
  bool get requiresSubscription => this != StrokeStyle.solid;
}

class DrawingLayer {
  const DrawingLayer({
    required this.id,
    required this.name,
    this.opacity = 1,
    this.visible = true,
  })  : assert(id > 0),
        assert(opacity >= 0 && opacity <= 1);

  final int id;
  final String name;
  final double opacity;
  final bool visible;

  DrawingLayer copyWith({
    String? name,
    double? opacity,
    bool? visible,
  }) {
    return DrawingLayer(
      id: id,
      name: name ?? this.name,
      opacity: (opacity ?? this.opacity).clamp(0.0, 1.0).toDouble(),
      visible: visible ?? this.visible,
    );
  }
}

class AdvancedStroke {
  AdvancedStroke({
    required Iterable<Offset> points,
    required this.style,
    required this.color,
    required double width,
    this.order = 0,
    this.layerId = 1,
    Iterable<double>? pressureSamples,
    DateTime? createdAt,
  })  : points = List<Offset>.unmodifiable(points),
        pressureSamples = List<double>.unmodifiable(pressureSamples ?? const <double>[]),
        width = width.clamp(1.0, 48.0).toDouble(),
        createdAt = createdAt ?? DateTime.now().toUtc();

  final List<Offset> points;
  final List<double> pressureSamples;
  final StrokeStyle style;
  final Color color;
  final double width;
  final int order;
  final int layerId;
  final DateTime createdAt;

  LayerCategory get layerCategory => LayerCategory.activeScribble;

  /// Smooths sampled pointer coordinates with midpoint quadratic segments.
  Path get path {
    final result = Path();
    if (points.isEmpty) return result;
    result.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return result;
    if (points.length == 2) {
      result.lineTo(points.last.dx, points.last.dy);
      return result;
    }
    for (var index = 1; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final midpoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      result.quadraticBezierTo(current.dx, current.dy, midpoint.dx, midpoint.dy);
    }
    result.lineTo(points.last.dx, points.last.dy);
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
    this.layerId = 1,
  });

  final StampKind kind;
  final Offset position;
  final double scale;
  final double rotationAngle;
  final Color fillColor;
  final Color strokeColor;
  final LayerCategory layerCategory;
  final int order;
  final int layerId;
}

class CanvasFill {
  const CanvasFill({
    required this.image,
    required this.logicalSize,
    this.layerId = 1,
  });

  final ui.Image image;
  final Size logicalSize;
  final int layerId;
}
