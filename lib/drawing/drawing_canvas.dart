import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/app_localizations.dart';
import 'drawing_controller.dart';
import 'drawing_models.dart';
import 'drawing_painters.dart';
import 'flood_fill.dart';

class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    super.key,
    required this.controller,
    required this.onFeedback,
    required this.onColorPicked,
    required this.onDoubleTapCanvas,
  });

  final DrawingController controller;
  final ValueChanged<String> onFeedback;
  final ValueChanged<Color> onColorPicked;
  final AsyncCallback onDoubleTapCanvas;

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  int? _activePointer;
  int? _doubleTapPointer;
  int? _eyedropperPointer;
  bool _eyedropperSampled = false;
  ui.Image? _magnifierImage;
  Offset? _magnifierPoint;
  int _sampleGeneration = 0;
  Offset? _activeStrokeStart;
  bool _activeStrokeMoved = false;
  Timer? _pendingTapCommit;
  final Set<int> _activePointers = <int>{};
  bool _rejectMultiTouchUntilReleased = false;
  bool _isFilling = false;
  final GlobalKey _paintKey = GlobalKey();

  DrawingController get controller => widget.controller;

  void _onPointerDown(PointerDownEvent event, Size size) {
    _activePointers.add(event.pointer);

    // A second stationary brush tap within the short tap window toggles the
    // studio chrome instead of leaving two unwanted dot marks on the canvas.
    if (_pendingTapCommit != null &&
        controller.activeTool == ActiveTool.brush &&
        !_rejectMultiTouchUntilReleased) {
      _pendingTapCommit!.cancel();
      _pendingTapCommit = null;
      controller.cancelActiveStroke(keepPartialDrawing: false);
      _doubleTapPointer = event.pointer;
      unawaited(widget.onDoubleTapCanvas());
      return;
    }

    if (_activePointers.length > 1) {
      _rejectMultiTouchUntilReleased = true;
      _pendingTapCommit?.cancel();
      _pendingTapCommit = null;
      if (_activePointer != null) {
        controller.cancelActiveStroke(keepPartialDrawing: false);
        _activePointer = null;
      }
      return;
    }
    if (_rejectMultiTouchUntilReleased || _doubleTapPointer != null) return;

    switch (controller.activeTool) {
      case ActiveTool.brush:
        _activePointer = event.pointer;
        _activeStrokeStart = event.localPosition;
        _activeStrokeMoved = false;
        controller.beginStroke(event.localPosition, pressure: event.pressure);
        break;
      case ActiveTool.stamp:
        controller.addStamp(event.localPosition);
        break;
      case ActiveTool.paintBucket:
        unawaited(_fillAt(event.localPosition, size));
        break;
      case ActiveTool.eyedropper:
        _eyedropperPointer = event.pointer;
        _eyedropperSampled = false;
        unawaited(_sampleColor(event.localPosition, size));
        controller.setActiveTool(ActiveTool.brush);
        break;
    }
  }

  void _onPointerMove(PointerMoveEvent event, Size size) {
    if (event.pointer == _eyedropperPointer) {
      unawaited(_sampleColor(event.localPosition, size));
      return;
    }
    if (event.pointer != _activePointer) return;
    final start = _activeStrokeStart;
    if (start != null && (event.localPosition - start).distance >= 3) {
      _activeStrokeMoved = true;
    }
    controller.appendActivePoint(event.localPosition, pressure: event.pressure);
  }

  void _onPointerUp(PointerEvent event) {
    if (event.pointer == _eyedropperPointer) {
      _eyedropperPointer = null;
      final sampled = _eyedropperSampled;
      _eyedropperSampled = false;
      _clearMagnifier();
      if (sampled) widget.onFeedback('Canvas color sampled.');
    }
    if (event.pointer == _doubleTapPointer) {
      _doubleTapPointer = null;
    } else if (event.pointer == _activePointer) {
      _activePointer = null;
      _activeStrokeStart = null;
      if (_activeStrokeMoved) {
        _activeStrokeMoved = false;
        controller.finishStroke();
      } else {
        _pendingTapCommit?.cancel();
        _pendingTapCommit = Timer(const Duration(milliseconds: 280), () {
          _pendingTapCommit = null;
          if (mounted) controller.finishStroke();
        });
      }
    }
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) _rejectMultiTouchUntilReleased = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _eyedropperPointer) {
      _eyedropperPointer = null;
      _eyedropperSampled = false;
      _clearMagnifier();
    }
    if (event.pointer == _doubleTapPointer) _doubleTapPointer = null;
    if (event.pointer == _activePointer) {
      _activePointer = null;
      _activeStrokeStart = null;
      controller.cancelActiveStroke(keepPartialDrawing: false);
    }
    if (_pendingTapCommit != null && event.pointer == _activePointer) {
      _pendingTapCommit!.cancel();
      _pendingTapCommit = null;
    }
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) _rejectMultiTouchUntilReleased = false;
  }

  Future<void> _sampleColor(Offset point, Size size) async {
    final renderObject = _paintKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;
    final generation = ++_sampleGeneration;
    ui.Image? snapshot;
    ui.Image? magnifier;
    try {
      snapshot = await renderObject.toImage(pixelRatio: 1);
      final x = point.dx.floor().clamp(0, snapshot.width - 1).toInt();
      final y = point.dy.floor().clamp(0, snapshot.height - 1).toInt();
      final data = await snapshot.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (data == null || !mounted || generation != _sampleGeneration) return;
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final offset = (y * snapshot.width + x) * 4;
      widget.onColorPicked(Color.fromARGB(
        bytes[offset + 3],
        bytes[offset],
        bytes[offset + 1],
        bytes[offset + 2],
      ));
      _eyedropperSampled = true;

      // Keep a separate image handle for the visible zoom lens. It is rendered
      // outside _paintKey so subsequent samples never capture the magnifier.
      magnifier = snapshot.clone();
      if (mounted && generation == _sampleGeneration) {
        final previous = _magnifierImage;
        setState(() {
          _magnifierImage = magnifier;
          _magnifierPoint = point;
        });
        magnifier = null;
        if (previous != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
        }
      }
    } catch (error) {
      debugPrint('Eyedropper sampling failed: $error');
      widget.onFeedback('Could not sample that canvas color.');
    } finally {
      magnifier?.dispose();
      snapshot?.dispose();
    }
  }

  void _clearMagnifier() {
    _sampleGeneration++;
    final previous = _magnifierImage;
    if (mounted) {
      setState(() {
        _magnifierImage = null;
        _magnifierPoint = null;
      });
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    } else {
      _magnifierImage = null;
      _magnifierPoint = null;
      previous?.dispose();
    }
  }

  Future<void> _fillAt(Offset point, Size size) async {
    if (_isFilling) return;
    final strings = AppLocalizations.of(context);
    final width = size.width.ceil();
    final height = size.height.ceil();
    if (width < 1 ||
        height < 1 ||
        width > DrawingController.maxRasterPixels ||
        height > DrawingController.maxRasterPixels ||
        width * height > DrawingController.maxRasterPixels) {
      widget.onFeedback(strings.translate('fill_region_too_large'));
      return;
    }

    setState(() => _isFilling = true);
    ui.Image? sourceImage;
    try {
      final recorder = ui.PictureRecorder();
      final recordingCanvas = Canvas(recorder, Offset.zero & size);
      paintFullSceneForRaster(recordingCanvas, size, controller);
      final picture = recorder.endRecording();
      try {
        sourceImage = await picture.toImage(width, height);
      } finally {
        picture.dispose();
      }

      final data = await sourceImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        widget.onFeedback(strings.translate('fill_failed'));
        return;
      }
      final pixels = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      sourceImage.dispose();
      sourceImage = null;

      final seedX = (point.dx * width / size.width).floor();
      final seedY = (point.dy * height / size.height).floor();
      final color = controller.bucketColor;
      final overlay = await compute<Map<String, Object?>, Uint8List>(
        floodFillRgba,
        <String, Object?>{
          'pixels': pixels,
          'width': width,
          'height': height,
          'seedX': seedX,
          'seedY': seedY,
          // Keep compatibility with the Flutter 3.10 minimum declared in pubspec.
          // ignore: deprecated_member_use
          'red': color.red,
          // ignore: deprecated_member_use
          'green': color.green,
          // ignore: deprecated_member_use
          'blue': color.blue,
          // ignore: deprecated_member_use
          'alpha': color.alpha,
          'tolerance': 18,
          'maxPixels': DrawingController.maxRasterPixels,
        },
      );

      if (overlay.lengthInBytes != width * height * 4) {
        widget.onFeedback(strings.translate('fill_failed'));
        return;
      }

      final imageCompleter = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        overlay,
        width,
        height,
        ui.PixelFormat.rgba8888,
        imageCompleter.complete,
      );
      final fillImage = await imageCompleter.future;
      if (!controller.addFillImage(fillImage, size)) {
        fillImage.dispose();
        widget.onFeedback(strings.translate('max_fill_layers'));
      }
    } catch (error, stackTrace) {
      debugPrint('Paint bucket failed safely: $error\n$stackTrace');
      widget.onFeedback(strings.translate('fill_failed'));
    } finally {
      sourceImage?.dispose();
      if (mounted) setState(() => _isFilling = false);
    }
  }

  @override
  void dispose() {
    _pendingTapCommit?.cancel();
    _sampleGeneration++;
    _magnifierImage?.dispose();
    _magnifierImage = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        controller.setCanvasSize(size);
        return SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => _onPointerDown(event, size),
                onPointerMove: (event) => _onPointerMove(event, size),
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: RepaintBoundary(
                  key: _paintKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CustomPaint(painter: BackgroundLayerPainter(controller)),
                      CustomPaint(painter: SceneLayerPainter(controller)),
                      CustomPaint(painter: ActiveStrokePainter(controller)),
                      if (_isFilling)
                        const IgnorePointer(
                          child: ColoredBox(
                            color: Color(0x16000000),
                            child: Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_magnifierImage != null && _magnifierPoint != null)
                Builder(
                  builder: (context) {
                    final point = _magnifierPoint!;
                    const lensSize = 104.0;
                    final desiredLeft = point.dx + 22;
                    final desiredTop = point.dy - lensSize - 22;
                    final left = (desiredLeft > size.width - lensSize
                            ? point.dx - lensSize - 22
                            : desiredLeft)
                        .clamp(0.0, (size.width - lensSize).clamp(0.0, size.width))
                        .toDouble();
                    final top = (desiredTop < 0 ? point.dy + 22 : desiredTop)
                        .clamp(0.0, (size.height - lensSize).clamp(0.0, size.height))
                        .toDouble();
                    return Positioned(
                      left: left,
                      top: top,
                      child: IgnorePointer(
                        child: SizedBox(
                          width: lensSize,
                          height: lensSize,
                          child: CustomPaint(
                            painter: _MagnifierLensPainter(
                              image: _magnifierImage!,
                              samplePoint: point,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}


class _MagnifierLensPainter extends CustomPainter {
  const _MagnifierLensPainter({
    required this.image,
    required this.samplePoint,
  });

  final ui.Image image;
  final Offset samplePoint;

  @override
  void paint(Canvas canvas, Size size) {
    final sourceSide = image.width < image.height
        ? image.width.toDouble()
        : image.height.toDouble();
    final cropSide = sourceSide < 34 ? sourceSide : 34.0;
    final maxLeft = (image.width - cropSide).clamp(0.0, image.width.toDouble());
    final maxTop = (image.height - cropSide).clamp(0.0, image.height.toDouble());
    final sourceLeft = (samplePoint.dx - cropSide / 2)
        .clamp(0.0, maxLeft)
        .toDouble();
    final sourceTop = (samplePoint.dy - cropSide / 2)
        .clamp(0.0, maxTop)
        .toDouble();
    final source = Rect.fromLTWH(sourceLeft, sourceTop, cropSide, cropSide);
    final destination = Offset.zero & size;
    final lensPath = Path()..addOval(destination);

    canvas.save();
    canvas.clipPath(lensPath);
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.high,
    );
    final center = size.center(Offset.zero);
    final crosshair = Paint()
      ..color = const Color(0xDDFFFFFF)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx - 15, center.dy),
      Offset(center.dx + 15, center.dy),
      crosshair,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 15),
      Offset(center.dx, center.dy + 15),
      crosshair,
    );
    canvas.restore();

    canvas.drawOval(
      destination.deflate(1.5),
      Paint()
        ..color = const Color(0xFF263238)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawOval(
      destination.deflate(5),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _MagnifierLensPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.samplePoint != samplePoint;
}
