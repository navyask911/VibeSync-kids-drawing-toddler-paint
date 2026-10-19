import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'drawing_controller.dart';
import 'drawing_models.dart';
import 'flood_fill_engine.dart';

class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    required this.controller,
    required this.onDrawingStateChanged,
    required this.onBucketResult,
    this.guideTemplate,
    super.key,
  });

  final DrawingController controller;
  final ValueChanged<bool> onDrawingStateChanged;
  final ValueChanged<String> onBucketResult;
  final StampKind? guideTemplate;

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final Map<String, ui.Image> _fillImages = {};
  final Map<String, Future<void>> _fillLoads = {};
  bool _bucketBusy = false;
  int _fillGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _syncFillImages();
  }

  @override
  void didUpdateWidget(covariant DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _disposeFillImages();
      widget.controller.addListener(_onControllerChanged);
      _syncFillImages();
    }
  }

  void _onControllerChanged() => _syncFillImages();

  void _disposeFillImages() {
    _fillGeneration++;
    for (final image in _fillImages.values) {
      image.dispose();
    }
    _fillImages.clear();
    _fillLoads.clear();
  }

  void _syncFillImages() {
    final existing = widget.controller.fills.map((layer) => layer.id).toSet();
    final staleIds = _fillImages.keys.where((id) => !existing.contains(id)).toList();
    for (final id in staleIds) {
      _fillImages.remove(id)?.dispose();
    }
    for (final layer in widget.controller.fills) {
      if (!_fillImages.containsKey(layer.id) && !_fillLoads.containsKey(layer.id)) {
        unawaited(_loadFillImage(layer));
      }
    }
  }

  Future<void> _loadFillImage(CanvasFillLayer layer) async {
    final id = layer.id;
    final generation = _fillGeneration;
    final operation = () async {
      try {
        final image = await ui.decodeImageFromList(Uint8List.fromList(layer.pngBytes));
        final stillExists = widget.controller.fills.any((item) => item.id == id);
        if (!mounted || generation != _fillGeneration || !stillExists) {
          image.dispose();
          return;
        }
        _fillImages[id] = image;
        widget.controller.notifyRasterImagesChanged();
      } catch (error) {
        debugPrint('Unable to decode saved fill layer $id: $error');
      } finally {
        _fillLoads.remove(id);
      }
    }();
    _fillLoads[id] = operation;
    await operation;
  }

  Future<void> _ensureFillImagesLoaded() async {
    for (final layer in widget.controller.fills.toList()) {
      if (_fillImages.containsKey(layer.id)) continue;
      final pending = _fillLoads[layer.id];
      if (pending != null) {
        await pending;
      } else {
        await _loadFillImage(layer);
      }
      if (!_fillImages.containsKey(layer.id)) {
        throw StateError('A saved raster fill layer could not be decoded.');
      }
    }
  }

  Future<Uint8List> _encodeRgbaAsPng(Uint8List rgba, int width, int height) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('PNG encoding returned no data.');
      return Uint8List.fromList(byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ));
    } finally {
      frame?.image.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<void> _paintBucketAt(Offset point, Size logicalSize) async {
    if (_bucketBusy) {
      widget.onBucketResult('bucket_busy');
      return;
    }
    if (logicalSize.width <= 0 || logicalSize.height <= 0 ||
        point.dx < 0 || point.dy < 0 ||
        point.dx >= logicalSize.width || point.dy >= logicalSize.height) return;

    _bucketBusy = true;
    final generation = _fillGeneration;
    ui.Image? composite;
    try {
      await _ensureFillImagesLoaded();
      if (!mounted || generation != _fillGeneration) return;

      const safePixelLimit = 2000000;
      final deviceRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0).toDouble();
      final logicalPixels = logicalSize.width * logicalSize.height;
      final ratio = math.min(deviceRatio, math.sqrt(safePixelLimit / logicalPixels))
          .clamp(0.5, 3.0).toDouble();
      final width = math.max(1, (logicalSize.width * ratio).round()).toInt();
      final height = math.max(1, (logicalSize.height * ratio).round()).toInt();
      if (width > safePixelLimit ~/ height) {
        widget.onBucketResult('bucket_failed');
        return;
      }

      final recorder = ui.PictureRecorder();
      final recordingCanvas = Canvas(recorder)..scale(ratio);
      _DrawingPainter(widget.controller, widget.guideTemplate, _fillImages)
          .paint(recordingCanvas, logicalSize);
      final picture = recorder.endRecording();
      try {
        composite = await picture.toImage(width, height);
      } finally {
        picture.dispose();
      }

      final rawData = await composite.toByteData(format: ui.ImageByteFormat.rawRgba);
      composite.dispose();
      composite = null;
      if (rawData == null) {
        widget.onBucketResult('bucket_failed');
        return;
      }
      final rawBytes = Uint8List.fromList(rawData.buffer.asUint8List(
        rawData.offsetInBytes,
        rawData.lengthInBytes,
      ));
      final color = widget.controller.bucketColor.toARGB32();
      final result = await floodFillRgba(
        sourceRgba: rawBytes,
        width: width,
        height: height,
        seedX: (point.dx * ratio).floor().clamp(0, width - 1).toInt(),
        seedY: (point.dy * ratio).floor().clamp(0, height - 1).toInt(),
        fillRgba: [
          (color >> 16) & 0xff,
          (color >> 8) & 0xff,
          color & 0xff,
          (color >> 24) & 0xff,
        ],
        tolerance: 18,
        maxPixels: safePixelLimit,
        maxRegionPixels: 500000,
      );
      if (!mounted || generation != _fillGeneration) return;
      if (result.exceededRegionLimit) {
        widget.onBucketResult('bucket_large_area');
        return;
      }
      if (result.filledPixels == 0) {
        widget.onBucketResult('bucket_no_change');
        return;
      }

      final pngBytes = await _encodeRgbaAsPng(result.overlayRgba, width, height);
      if (!mounted || generation != _fillGeneration) return;
      final committed = widget.controller.commitFillLayer(
        pngBytes: pngBytes,
        logicalWidth: logicalSize.width,
        logicalHeight: logicalSize.height,
      );
      if (!committed) {
        widget.onBucketResult('bucket_storage_limit');
        return;
      }
      widget.onBucketResult('bucket_filled');
    } catch (error, stackTrace) {
      debugPrint('Paint bucket failed safely: $error\n$stackTrace');
      if (mounted) widget.onBucketResult('bucket_failed');
    } finally {
      composite?.dispose();
      _bucketBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = constraints.biggest;
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (widget.controller.activeTool == ActiveTool.stamp) {
                    widget.controller.placeSelectedStamp(event.localPosition);
                    return;
                  }
                  if (widget.controller.activeTool == ActiveTool.paintBucket) {
                    unawaited(_paintBucketAt(event.localPosition, canvasSize));
                    return;
                  }
                  widget.controller.beginStroke(event.localPosition);
                  widget.onDrawingStateChanged(widget.controller.isDrawing);
                },
                onPointerMove: (event) {
                  if (widget.controller.isDrawing) widget.controller.extendStroke(event.localPosition);
                },
                onPointerUp: (_) {
                  widget.controller.endStroke();
                  widget.onDrawingStateChanged(false);
                },
                onPointerCancel: (_) {
                  widget.controller.cancelStroke(keepPartialStroke: true);
                  widget.onDrawingStateChanged(false);
                },
                child: CustomPaint(
                  painter: _DrawingPainter(widget.controller, widget.guideTemplate, _fillImages),
                  size: canvasSize,
                ),
              );
            },
          ),
        ),
      );

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _disposeFillImages();
    super.dispose();
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter(this.controller, this.guideTemplate, this.fillImages) : super(repaint: controller);
  final DrawingController controller;
  final StampKind? guideTemplate;
  final Map<String, ui.Image> fillImages;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(controller.backgroundColor, BlendMode.src);
    for (final layer in controller.fills) {
      final image = fillImages[layer.id];
      if (image == null) continue;
      final sourceRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final destinationRect = Rect.fromLTWH(0, 0, layer.logicalWidth, layer.logicalHeight);
      canvas.drawImageRect(image, sourceRect, destinationRect, Paint()..filterQuality = FilterQuality.low);
    }

    final guide = guideTemplate;
    if (guide != null && size.width > 0 && size.height > 0) {
      _paintStamp(canvas, CanvasStamp(
        id: 'template-guide',
        kind: guide,
        position: Offset(size.width / 2, size.height / 2),
        scale: (math.min(size.width, size.height) * 0.0034).clamp(0.7, 1.7).toDouble(),
        rotationAngle: 0,
        fillColor: Colors.transparent,
        strokeColor: const Color(0xFFB8C3D1),
        layerCategory: guide.defaultLayer,
        order: -1,
      ));
    }

    for (final stamp in sortStampsByLayer(controller.stamps)) {
      _paintStamp(canvas, stamp);
    }
    for (final stroke in controller.strokes) {
      _paintStroke(canvas, stroke);
    }

    final activeStroke = controller.activeStroke;
    if (activeStroke != null) _paintStroke(canvas, activeStroke);
    canvas.restore();
  }

  void _paintStroke(Canvas canvas, AdvancedStroke stroke) {
    final path = stroke.toPath();
    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      if (stroke.style == StrokeStyle.neon) {
        canvas.drawCircle(point, stroke.width * 1.1, Paint()
          ..color = stroke.color.withOpacity(0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.width * 0.8));
        canvas.drawCircle(point, math.max(1.0, stroke.width * 0.32).toDouble(),
            Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(point, stroke.width / 2,
            Paint()..color = stroke.style == StrokeStyle.rainbow ? Colors.purple : stroke.color);
      }
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (stroke.style) {
      case StrokeStyle.solid:
        paint.color = stroke.color;
        canvas.drawPath(path, paint);
        break;
      case StrokeStyle.neon:
        final glow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.width * 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..color = stroke.color.withOpacity(0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.width * 0.75);
        canvas.drawPath(path, glow);
        paint
          ..color = Colors.white
          ..strokeWidth = math.max(1.0, stroke.width * 0.42).toDouble();
        canvas.drawPath(path, paint);
        break;
      case StrokeStyle.rainbow:
        final bounds = path.getBounds();
        if (bounds.width < 0.5 || bounds.height < 0.5) {
          paint.color = stroke.color;
        } else {
          paint.shader = ui.Gradient.linear(
            bounds.topLeft,
            bounds.bottomRight,
            const [
              Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00),
              Color(0xFF34C759), Color(0xFF00C7BE), Color(0xFF007AFF),
              Color(0xFFAF52DE),
            ],
          );
        }
        canvas.drawPath(path, paint);
        paint.shader = null;
        break;
    }
  }

  void _paintStamp(Canvas canvas, CanvasStamp stamp) {
    canvas.save();
    canvas.translate(stamp.position.dx, stamp.position.dy);
    canvas.rotate(stamp.rotationAngle);
    canvas.scale(stamp.scale);
    final fill = Paint()
      ..color = stamp.fillColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final outline = Paint()
      ..color = stamp.strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    Path poly(List<Offset> points) {
      final p = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) { p.lineTo(point.dx, point.dy); }
      return p..close();
    }

    switch (stamp.kind) {
      case StampKind.puppy:
        canvas.drawOval(const Rect.fromLTWH(-42, -40, 84, 80), fill);
        canvas.drawOval(const Rect.fromLTWH(-42, -40, 84, 80), outline);
        canvas.drawOval(const Rect.fromLTWH(-52, -35, 23, 42), fill);
        canvas.drawOval(const Rect.fromLTWH(29, -35, 23, 42), fill);
        canvas.drawCircle(const Offset(-15, -10), 3.5, Paint()..color = stamp.strokeColor);
        canvas.drawCircle(const Offset(15, -10), 3.5, Paint()..color = stamp.strokeColor);
        canvas.drawOval(const Rect.fromLTWH(-8, 0, 16, 10), Paint()..color = stamp.strokeColor);
        canvas.drawArc(const Rect.fromLTWH(-16, 0, 32, 18), 0.2, 2.7, false, outline);
        break;
      case StampKind.sunshine:
        canvas.drawCircle(Offset.zero, 28, fill);
        canvas.drawCircle(Offset.zero, 28, outline);
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          canvas.drawLine(Offset(math.cos(a) * 35, math.sin(a) * 35),
              Offset(math.cos(a) * 45, math.sin(a) * 45), outline);
        }
        canvas.drawCircle(const Offset(-9, -5), 3, Paint()..color = stamp.strokeColor);
        canvas.drawCircle(const Offset(9, -5), 3, Paint()..color = stamp.strokeColor);
        canvas.drawArc(const Rect.fromLTWH(-11, -1, 22, 15), 0.2, 2.7, false, outline);
        break;
      case StampKind.rocket:
        canvas.drawOval(const Rect.fromLTWH(-22, -36, 44, 72), fill);
        canvas.drawOval(const Rect.fromLTWH(-22, -36, 44, 72), outline);
        canvas.drawPath(poly([const Offset(-22, 15), const Offset(-40, 36), const Offset(-17, 30)]), fill);
        canvas.drawPath(poly([const Offset(22, 15), const Offset(40, 36), const Offset(17, 30)]), fill);
        canvas.drawPath(poly([const Offset(-14, -33), const Offset(0, -50), const Offset(14, -33)]), fill);
        canvas.drawCircle(const Offset(0, -12), 8, outline);
        canvas.drawPath(poly([const Offset(-9, 35), const Offset(0, 47), const Offset(9, 35)]), Paint()..color = stamp.strokeColor);
        break;
      case StampKind.unicorn:
        canvas.drawOval(const Rect.fromLTWH(-39, -30, 76, 63), fill);
        canvas.drawOval(const Rect.fromLTWH(-39, -30, 76, 63), outline);
        canvas.drawPath(poly([const Offset(-7, -28), const Offset(2, -52), const Offset(12, -27)]), outline);
        canvas.drawPath(poly([const Offset(-30, -27), const Offset(-44, -44), const Offset(-16, -36)]), fill);
        canvas.drawCircle(const Offset(-14, -6), 3, Paint()..color = stamp.strokeColor);
        canvas.drawArc(const Rect.fromLTWH(-15, 0, 24, 18), 0.1, 2.8, false, outline);
        break;
      case StampKind.house:
        canvas.drawRect(const Rect.fromLTWH(-31, -10, 62, 48), fill);
        canvas.drawRect(const Rect.fromLTWH(-31, -10, 62, 48), outline);
        final roof = poly([const Offset(-40, -10), const Offset(0, -43), const Offset(40, -10)]);
        canvas.drawPath(roof, fill);
        canvas.drawPath(roof, outline);
        canvas.drawRect(const Rect.fromLTWH(-7, 12, 14, 26), outline);
        canvas.drawRect(const Rect.fromLTWH(-24, 0, 11, 11), outline);
        canvas.drawRect(const Rect.fromLTWH(13, 0, 11, 11), outline);
        break;
      case StampKind.flower:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          final center = Offset(math.cos(a) * 18, math.sin(a) * 18);
          canvas.drawCircle(center, 13, fill);
          canvas.drawCircle(center, 13, outline);
        }
        canvas.drawCircle(Offset.zero, 12, outline);
        canvas.drawLine(const Offset(0, 27), const Offset(0, 46), outline);
        canvas.drawOval(const Rect.fromLTWH(0, 32, 18, 8), outline);
        break;
      case StampKind.pond:
        const pondRect = Rect.fromLTRB(-46, -30, 46, 30);
        canvas.drawOval(pondRect, fill);
        canvas.drawOval(pondRect, outline);
        canvas.drawArc(const Rect.fromLTWH(-24, -12, 38, 18), 0.2, 2.4, false, outline);
        canvas.drawArc(const Rect.fromLTWH(-5, 3, 37, 18), 0.2, 2.4, false, outline);
        break;
      case StampKind.fish:
        final body = Path()..addOval(const Rect.fromLTWH(-30, -18, 54, 36));
        canvas.drawPath(body, fill);
        canvas.drawPath(body, outline);
        final tail = poly([const Offset(20, 0), const Offset(42, -16), const Offset(42, 16)]);
        canvas.drawPath(tail, fill);
        canvas.drawPath(tail, outline);
        canvas.drawCircle(const Offset(-14, -4), 3, Paint()..color = stamp.strokeColor);
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter old) =>
      old.controller != controller ||
      old.controller.revision != controller.revision ||
      old.guideTemplate != guideTemplate ||
      old.fillImages != fillImages;
}