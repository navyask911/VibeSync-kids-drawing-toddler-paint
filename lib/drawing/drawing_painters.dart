import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'drawing_controller.dart';
import 'drawing_models.dart';

class BackgroundLayerPainter extends CustomPainter {
  BackgroundLayerPainter(this.controller) : super(repaint: controller.backgroundRepaint);

  final DrawingController controller;

  @override
  void paint(Canvas canvas, Size size) {
    paintBackgroundLayer(canvas, size, controller);
  }

  @override
  bool shouldRepaint(covariant BackgroundLayerPainter oldDelegate) =>
      oldDelegate.controller != controller;
}

class SceneLayerPainter extends CustomPainter {
  SceneLayerPainter(this.controller) : super(repaint: controller.sceneRepaint);

  final DrawingController controller;

  @override
  void paint(Canvas canvas, Size size) {
    paintSceneLayer(canvas, size, controller);
  }

  @override
  bool shouldRepaint(covariant SceneLayerPainter oldDelegate) =>
      oldDelegate.controller != controller;
}

class ActiveStrokePainter extends CustomPainter {
  ActiveStrokePainter(this.controller) : super(repaint: controller.activeRepaint);

  final DrawingController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final points = controller.activePoints;
    if (points.isEmpty) return;
    _drawStroke(
      canvas,
      AdvancedStroke(
        points: points,
        color: controller.activeStrokeColor,
        width: controller.activeStrokeWidth,
        style: controller.activeStrokeStyle,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) =>
      oldDelegate.controller != controller;
}

/// Paints the background, template, fill overlays, stamps and committed strokes
/// into a recorder using the same ordering as the visible canvas.
void paintFullSceneForRaster(
  Canvas canvas,
  Size size,
  DrawingController controller,
) {
  paintBackgroundLayer(canvas, size, controller);
  paintSceneLayer(canvas, size, controller);
}

void paintBackgroundLayer(
  Canvas canvas,
  Size size,
  DrawingController controller,
) {
  canvas.drawColor(controller.backgroundColor, BlendMode.src);
  _drawColoringTemplate(canvas, size, controller.selectedPage);

  for (final fill in controller.fills) {
    final image = fill.image;
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, source, Offset.zero & size, Paint());
  }
}

void paintSceneLayer(
  Canvas canvas,
  Size size,
  DrawingController controller,
) {
  final stamps = controller.stamps.toList()
    ..sort((a, b) {
      final layerOrder = a.layerCategory.index.compareTo(b.layerCategory.index);
      return layerOrder != 0 ? layerOrder : a.order.compareTo(b.order);
    });
  for (final stamp in stamps) {
    _drawStamp(canvas, stamp);
  }

  final strokes = controller.strokes.toList()
    ..sort((a, b) {
      final layerOrder = a.layerCategory.index.compareTo(b.layerCategory.index);
      return layerOrder != 0 ? layerOrder : a.order.compareTo(b.order);
    });
  for (final stroke in strokes) {
    _drawStroke(canvas, stroke);
  }
}

void _drawStroke(Canvas canvas, AdvancedStroke stroke) {
  if (stroke.points.isEmpty) return;
  final path = stroke.path;
  if (stroke.points.length == 1) {
    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
    return;
  }

  final bounds = path.getBounds().inflate(stroke.width * 3 + 2);
  final basePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke.width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  switch (stroke.style) {
    case StrokeStyle.solid:
      canvas.drawPath(path, basePaint..color = stroke.color);
      break;
    case StrokeStyle.neon:
      canvas.save();
      canvas.clipRect(bounds);
      canvas.saveLayer(
        bounds,
        Paint()..imageFilter = ui.ImageFilter.blur(
          sigmaX: (stroke.width * 0.75).clamp(2.0, 8.0).toDouble(),
          sigmaY: (stroke.width * 0.75).clamp(2.0, 8.0).toDouble(),
        ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.width * 2.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = stroke.color.withOpacity(0.85),
      );
      canvas.restore();
      canvas.drawPath(
        path,
        basePaint
          ..strokeWidth = math.max(1.0, stroke.width * 0.48).toDouble()
          ..color = Colors.white.withOpacity(0.95),
      );
      canvas.restore();
      break;
    case StrokeStyle.rainbow:
      final gradientBounds = path.getBounds();
      final left = gradientBounds.left;
      final top = gradientBounds.top;
      final right = gradientBounds.width < 1
          ? left + 1
          : gradientBounds.right;
      final bottom = gradientBounds.height < 1
          ? top + 1
          : gradientBounds.bottom;
      final shader = ui.Gradient.linear(
        Offset(left, top),
        Offset(right, bottom),
        const <Color>[
          Color(0xFFE53935),
          Color(0xFFFF9800),
          Color(0xFFFFEB3B),
          Color(0xFF43A047),
          Color(0xFF039BE5),
          Color(0xFF8E24AA),
        ],
        const <double>[0, 0.2, 0.4, 0.6, 0.8, 1],
      );
      canvas.drawPath(path, basePaint..shader = shader);
      break;
  }
}

void _drawStamp(Canvas canvas, CanvasStamp stamp) {
  canvas.save();
  canvas.translate(stamp.position.dx, stamp.position.dy);
  canvas.rotate(stamp.rotationAngle);
  canvas.scale(stamp.scale.clamp(0.2, 3.0).toDouble());

  final fill = Paint()
    ..color = stamp.fillColor
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  final outline = Paint()
    ..color = stamp.strokeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  switch (stamp.kind) {
    case StampKind.pond:
      final pond = Path()
        ..addOval(const Rect.fromLTRB(-45, -20, 45, 20));
      canvas.drawPath(pond, fill);
      canvas.drawPath(pond, outline);
      canvas.drawArc(
        const Rect.fromLTRB(-26, -12, 20, 10),
        math.pi,
        math.pi * 0.8,
        false,
        Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      break;
    case StampKind.house:
      final body = Path()
        ..addRect(const Rect.fromLTRB(-32, -2, 32, 38));
      final roof = Path()
        ..moveTo(-42, -2)
        ..lineTo(0, -38)
        ..lineTo(42, -2)
        ..close();
      canvas.drawPath(body, fill);
      canvas.drawPath(body, outline);
      canvas.drawPath(roof, fill);
      canvas.drawPath(roof, outline);
      final door = Path()..addRect(const Rect.fromLTRB(-8, 14, 8, 38));
      canvas.drawPath(door, outline);
      canvas.drawRect(const Rect.fromLTRB(-25, 6, -13, 18), outline);
      canvas.drawRect(const Rect.fromLTRB(13, 6, 25, 18), outline);
      break;
    case StampKind.flower:
      final stem = Path()
        ..moveTo(0, 4)
        ..quadraticBezierTo(-3, 22, 0, 38);
      canvas.drawPath(
        stem,
        Paint()
          ..color = const Color(0xFF388E3C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      final leaf = Path()
        ..moveTo(0, 24)
        ..quadraticBezierTo(-24, 12, -22, 3)
        ..quadraticBezierTo(-3, 5, 0, 24)
        ..close();
      canvas.drawPath(
        leaf,
        Paint()
          ..color = const Color(0xFF66BB6A)
          ..style = PaintingStyle.fill,
      );
      final petalCenters = <Offset>[
        const Offset(0, -18),
        const Offset(18, -10),
        const Offset(18, 9),
        const Offset(0, 17),
        const Offset(-18, 9),
        const Offset(-18, -10),
      ];
      for (final center in petalCenters) {
        canvas.drawCircle(center, 11, fill);
        canvas.drawCircle(center, 11, outline);
      }
      canvas.drawCircle(const Offset(0, 0), 10, Paint()..color = const Color(0xFFFFC107));
      canvas.drawCircle(const Offset(0, 0), 10, outline);
      break;
    case StampKind.fish:
      final body = Path()
        ..addOval(const Rect.fromLTRB(-36, -18, 23, 18));
      final tail = Path()
        ..moveTo(19, 0)
        ..lineTo(43, -19)
        ..lineTo(43, 19)
        ..close();
      canvas.drawPath(body, fill);
      canvas.drawPath(body, outline);
      canvas.drawPath(tail, fill);
      canvas.drawPath(tail, outline);
      canvas.drawCircle(
        const Offset(-18, -5),
        3.5,
        Paint()..color = stamp.strokeColor,
      );
      break;
  }

  canvas.restore();
}

void _drawColoringTemplate(Canvas canvas, Size size, ColoringPage page) {
  if (page == ColoringPage.freeDraw) return;

  final scale = (math.min(size.width, size.height) / 430).clamp(0.35, 1.15).toDouble();
  canvas.save();
  canvas.translate(size.width / 2, size.height / 2);
  canvas.scale(scale);

  final line = Paint()
    ..color = const Color(0xFF94A3B8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final softFill = Paint()
    ..color = const Color(0xFFF8FAFC)
    ..style = PaintingStyle.fill;

  switch (page) {
    case ColoringPage.freeDraw:
      break;
    case ColoringPage.puppy:
      canvas.drawCircle(Offset.zero, 82, line);
      canvas.drawOval(const Rect.fromLTRB(-118, -65, -62, 32), line);
      canvas.drawOval(const Rect.fromLTRB(62, -65, 118, 32), line);
      canvas.drawOval(const Rect.fromLTRB(-35, -4, 35, 45), line);
      canvas.drawCircle(const Offset(-30, -22), 7, Paint()..color = const Color(0xFF64748B));
      canvas.drawCircle(const Offset(30, -22), 7, Paint()..color = const Color(0xFF64748B));
      canvas.drawOval(const Rect.fromLTRB(-10, 6, 10, 18), Paint()..color = const Color(0xFF64748B));
      canvas.drawArc(const Rect.fromLTRB(-24, 14, 24, 47), 0, math.pi, false, line);
      break;
    case ColoringPage.sunshine:
      canvas.drawCircle(Offset.zero, 64, line);
      for (var index = 0; index < 12; index++) {
        final angle = index * math.pi / 6;
        final start = Offset(math.cos(angle) * 78, math.sin(angle) * 78);
        final end = Offset(math.cos(angle) * 110, math.sin(angle) * 110);
        canvas.drawLine(start, end, line);
      }
      canvas.drawCircle(const Offset(-22, -12), 5, Paint()..color = const Color(0xFF64748B));
      canvas.drawCircle(const Offset(22, -12), 5, Paint()..color = const Color(0xFF64748B));
      canvas.drawArc(const Rect.fromLTRB(-26, -2, 26, 35), 0.25, math.pi - 0.5, false, line);
      break;
    case ColoringPage.rocket:
      final body = Path()
        ..moveTo(0, -122)
        ..cubicTo(48, -88, 50, 10, 32, 56)
        ..lineTo(-32, 56)
        ..cubicTo(-50, 10, -48, -88, 0, -122)
        ..close();
      canvas.drawPath(body, softFill);
      canvas.drawPath(body, line);
      final leftFin = Path()
        ..moveTo(-32, 24)
        ..lineTo(-72, 68)
        ..lineTo(-25, 59)
        ..close();
      final rightFin = Path()
        ..moveTo(32, 24)
        ..lineTo(72, 68)
        ..lineTo(25, 59)
        ..close();
      canvas.drawPath(leftFin, softFill);
      canvas.drawPath(leftFin, line);
      canvas.drawPath(rightFin, softFill);
      canvas.drawPath(rightFin, line);
      canvas.drawCircle(const Offset(0, -42), 18, line);
      canvas.drawPath(
        Path()
          ..moveTo(-16, 62)
          ..quadraticBezierTo(0, 95, -4, 116)
          ..moveTo(16, 62)
          ..quadraticBezierTo(0, 95, 4, 116),
        line,
      );
      break;
    case ColoringPage.unicorn:
      canvas.drawOval(const Rect.fromLTRB(-76, -42, 65, 72), softFill);
      canvas.drawOval(const Rect.fromLTRB(-76, -42, 65, 72), line);
      final horn = Path()
        ..moveTo(-30, -38)
        ..lineTo(-2, -114)
        ..lineTo(12, -31)
        ..close();
      canvas.drawPath(horn, softFill);
      canvas.drawPath(horn, line);
      canvas.drawPath(
        Path()
          ..moveTo(28, -38)
          ..quadraticBezierTo(74, -60, 54, -6)
          ..quadraticBezierTo(34, -16, 28, -38),
        line,
      );
      canvas.drawCircle(const Offset(-24, -4), 5, Paint()..color = const Color(0xFF64748B));
      canvas.drawArc(const Rect.fromLTRB(-18, 5, 18, 32), 0.15, math.pi - 0.3, false, line);
      break;
  }

  canvas.restore();
}
