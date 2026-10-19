import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  });

  final DrawingController controller;
  final ValueChanged<String> onFeedback;

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  int? _activePointer;
  bool _isFilling = false;

  DrawingController get controller => widget.controller;

  void _onPointerDown(PointerDownEvent event, Size size) {
    if (_activePointer != null) return;
    switch (controller.activeTool) {
      case ActiveTool.brush:
        _activePointer = event.pointer;
        controller.beginStroke(event.localPosition);
        break;
      case ActiveTool.stamp:
        controller.addStamp(event.localPosition);
        break;
      case ActiveTool.paintBucket:
        unawaited(_fillAt(event.localPosition, size));
        break;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer == _activePointer) {
      controller.appendActivePoint(event.localPosition);
    }
  }

  void _onPointerUp(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    controller.finishStroke();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    controller.cancelActiveStroke(keepPartialDrawing: true);
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
          'red': (color.r * 255).round(),
          'green': (color.g * 255).round(),
          'blue': (color.b * 255).round(),
          'alpha': (color.a * 255).round(),
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return SizedBox.expand(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _onPointerDown(event, size),
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: RepaintBoundary(
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
        );
      },
    );
  }
}
