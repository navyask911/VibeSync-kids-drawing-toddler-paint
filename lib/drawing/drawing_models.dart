import 'package:flutter/material.dart';

enum StrokeStyle { solid, neon, rainbow }
enum LayerCategory { background, sceneryPond, architectureHouse, foregroundFlora, activeScribble }
enum ActiveTool { brush, paintBucket, stamp }
enum StampKind { puppy, sunshine, rocket, unicorn, house, flower, pond, fish }

extension StampKindLayer on StampKind {
  LayerCategory get defaultLayer => switch (this) {
        StampKind.pond => LayerCategory.sceneryPond,
        StampKind.house => LayerCategory.architectureHouse,
        _ => LayerCategory.foregroundFlora,
      };
}

@immutable
class AdvancedStroke {
  AdvancedStroke({
    required List<Offset> points,
    required this.style,
    required this.color,
    required double width,
  })  : points = List<Offset>.unmodifiable(points),
        width = width.clamp(1.0, 64.0).toDouble();

  final List<Offset> points;
  final StrokeStyle style;
  final Color color;
  final double width;

  Path toPath() {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  Map<String, Object?> toJson() => {
        'points': points.map((p) => [p.dx, p.dy]).toList(growable: false),
        'style': style.name,
        'color': color.value,
        'width': width,
      };

  factory AdvancedStroke.fromJson(Map<String, dynamic> json) {
    final points = <Offset>[];
    final rawPoints = json['points'];
    if (rawPoints is List) {
      for (final raw in rawPoints) {
        if (raw is List && raw.length >= 2 && raw[0] is num && raw[1] is num) {
          final x = (raw[0] as num).toDouble();
          final y = (raw[1] as num).toDouble();
          if (x.isFinite && y.isFinite) points.add(Offset(x, y));
        }
      }
    }
    return AdvancedStroke(
      points: points,
      style: StrokeStyle.values.firstWhere(
        (s) => s.name == json['style'],
        orElse: () => StrokeStyle.solid,
      ),
      color: Color((json['color'] as num?)?.toInt() ?? Colors.deepOrange.value),
      width: (json['width'] as num?)?.toDouble() ?? 6,
    );
  }
}

@immutable
class CanvasStamp {
  const CanvasStamp({
    required this.id,
    required this.kind,
    required this.position,
    required this.scale,
    required this.rotationAngle,
    required this.fillColor,
    required this.strokeColor,
    required this.layerCategory,
    required this.order,
  });

  final String id;
  final StampKind kind;
  final Offset position;
  final double scale;
  final double rotationAngle;
  final Color fillColor;
  final Color strokeColor;
  final LayerCategory layerCategory;
  final int order;

  Map<String, Object?> toJson() => {
        'id': id, 'kind': kind.name, 'x': position.dx, 'y': position.dy,
        'scale': scale, 'rotation': rotationAngle, 'fill': fillColor.value,
        'stroke': strokeColor.value, 'layer': layerCategory.name, 'order': order,
      };

  factory CanvasStamp.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback) {
      final value = json[key];
      return value is num && value.toDouble().isFinite ? value.toDouble() : fallback;
    }

    final kind = StampKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => StampKind.flower,
    );
    return CanvasStamp(
      id: json['id'] as String? ?? ('restored-' + ((json['order'] ?? 0).toString())),
      kind: kind,
      position: Offset(number('x', 0), number('y', 0)),
      scale: number('scale', 1).clamp(0.25, 4.0).toDouble(),
      rotationAngle: number('rotation', 0),
      fillColor: Color((json['fill'] as num?)?.toInt() ?? Colors.amber.value),
      strokeColor: Color((json['stroke'] as num?)?.toInt() ?? Colors.brown.value),
      layerCategory: LayerCategory.values.firstWhere(
        (layer) => layer.name == json['layer'],
        orElse: () => kind.defaultLayer,
      ),
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

List<CanvasStamp> sortStampsByLayer(Iterable<CanvasStamp> source) {
  final sorted = source.toList()
    ..sort((a, b) {
      final layerOrder = a.layerCategory.index.compareTo(b.layerCategory.index);
      return layerOrder != 0 ? layerOrder : a.order.compareTo(b.order);
    });
  return List<CanvasStamp>.unmodifiable(sorted);
}

@immutable
class DrawingSnapshot {
  const DrawingSnapshot({
    required this.strokes,
    required this.stamps,
    required this.backgroundColor,
  });

  final List<AdvancedStroke> strokes;
  final List<CanvasStamp> stamps;
  final Color backgroundColor;
}