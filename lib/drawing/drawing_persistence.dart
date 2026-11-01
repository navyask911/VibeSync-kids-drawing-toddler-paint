import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'drawing_controller.dart';
import 'drawing_models.dart';

/// Versioned, bounded app-private autosave. Artwork is never uploaded.
class DrawingPersistence {
  DrawingPersistence({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;
  static const int _version = 1;
  static const int _maxFileBytes = 20 * 1024 * 1024;
  static const int _maxStrokes = 5000;
  static const int _maxPoints = 200000;
  static const int _maxStamps = 2000;
  static const int _maxTotalFillPixels = 2000000;

  Future<void> _writeQueue = Future<void>.value();

  Future<File> _file() async {
    final directory = await _documentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}vibesync_drawing_autosave_v1.json');
  }

  Future<void> save(DrawingController controller) {
    final result = Completer<void>();
    _writeQueue = _writeQueue.catchError((Object _) {}).then((_) async {
      try {
        await _saveNow(controller);
        result.complete();
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  /// Encode the current drawing in a bounded, versioned JSON backup.
  Future<Uint8List> exportBackup(DrawingController controller) async {
    final strokes = controller.strokes.toList(growable: false);
    final stamps = controller.stamps.toList(growable: false);
    final fills = controller.fills.toList(growable: false);
    if (strokes.length > _maxStrokes || stamps.length > _maxStamps) {
      throw StateError('Drawing exceeds the safe backup item limit.');
    }
    var pointCount = 0;
    for (final stroke in strokes) {
      pointCount += stroke.points.length;
      if (pointCount > _maxPoints) {
        throw StateError('Drawing exceeds the safe backup point limit.');
      }
    }
    final snapshot = <String, Object?>{
      'version': _version,
      // ignore: deprecated_member_use
      'backgroundColor': controller.backgroundColor.value,
      // ignore: deprecated_member_use
      'brushColor': controller.brushColor.value,
      // ignore: deprecated_member_use
      'bucketColor': controller.bucketColor.value,
      // ignore: deprecated_member_use
      'stampFillColor': controller.stampFillColor.value,
      // ignore: deprecated_member_use
      'stampStrokeColor': controller.stampStrokeColor.value,
      'brushWidth': controller.brushWidth,
      'brushStyle': controller.brushStyle.name,
      'activeTool': controller.activeTool.name,
      'selectedStamp': controller.selectedStamp.name,
      'selectedPage': controller.selectedPage.name,
      'strokes': strokes.map(_encodeStroke).toList(growable: false),
      'stamps': stamps.map(_encodeStamp).toList(growable: false),
      'fills': await Future.wait(fills.map(_encodeFill)),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(snapshot)));
    if (bytes.length > _maxFileBytes) {
      throw StateError('Drawing backup exceeds the safe file-size limit.');
    }
    return bytes;
  }

  Future<void> _saveNow(DrawingController controller) async {
    final bytes = await exportBackup(controller);
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary =
        File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    try {
      await temporary.rename(file.path);
    } catch (_) {
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    }
  }

  Map<String, Object?> _encodeStroke(AdvancedStroke stroke) => <String, Object?>{
        'points': stroke.points.map((p) => <double>[p.dx, p.dy]).toList(growable: false),
        'style': stroke.style.name,
        // ignore: deprecated_member_use
        'color': stroke.color.value,
        'width': stroke.width,
        'order': stroke.order,
      };

  Map<String, Object?> _encodeStamp(CanvasStamp stamp) => <String, Object?>{
        'kind': stamp.kind.name,
        'x': stamp.position.dx,
        'y': stamp.position.dy,
        'scale': stamp.scale,
        'rotation': stamp.rotationAngle,
        // ignore: deprecated_member_use
        'fillColor': stamp.fillColor.value,
        // ignore: deprecated_member_use
        'strokeColor': stamp.strokeColor.value,
        'layerCategory': stamp.layerCategory.name,
        'order': stamp.order,
      };

  Future<Map<String, Object?>> _encodeFill(CanvasFill fill) async {
    // Keep image bytes valid even if undo/clear happens during encoding.
    final image = fill.image.clone();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not encode a saved fill layer.');
      final png = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      return <String, Object?>{
        'pngBase64': base64Encode(png),
        'logicalWidth': fill.logicalSize.width,
        'logicalHeight': fill.logicalSize.height,
      };
    } finally {
      image.dispose();
    }
  }

  Future<bool> restore(DrawingController controller) async {
    final file = await _file();
    if (!await file.exists()) return false;
    return restoreBackup(await file.readAsBytes(), controller);
  }

  /// Restore a selected backup after validating its format and size limits.
  Future<bool> restoreBackup(
    Uint8List bytes,
    DrawingController controller,
  ) async {
    if (bytes.isEmpty || bytes.length > _maxFileBytes) {
      throw const FormatException('Backup is outside the accepted size range.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> || decoded['version'] != _version) {
      throw const FormatException('Backup format is not supported.');
    }

    
    
        final strokes = _decodeStrokes(decoded['strokes']);
        final stamps = _decodeStamps(decoded['stamps']);
        final fills = <CanvasFill>[];
        var totalFillPixels = 0;
        var ownershipTransferred = false;
        try {
          final rawFills = decoded['fills'];
          if (rawFills is! List || rawFills.length > DrawingController.maxFillLayers) {
            throw const FormatException('Invalid saved fill collection.');
          }
          for (final raw in rawFills) {
            if (raw is! Map<String, dynamic> || raw['pngBase64'] is! String) {
              throw const FormatException('Invalid saved fill image.');
            }
            final png = base64Decode(raw['pngBase64'] as String);
            if (png.isEmpty || png.length > _maxFileBytes) {
              throw const FormatException('Saved fill image is outside size limits.');
            }
            final codec = await ui.instantiateImageCodec(png);
            try {
              final frame = await codec.getNextFrame();
              final image = frame.image;
              final pixels = image.width * image.height;
              totalFillPixels += pixels;
              if (image.width <= 0 ||
                  image.height <= 0 ||
                  pixels > DrawingController.maxRasterPixels ||
                  totalFillPixels > _maxTotalFillPixels) {
                image.dispose();
                throw const FormatException('Saved fill image exceeds pixel limits.');
              }
              fills.add(CanvasFill(
                image: image,
                logicalSize: Size(
                  _readDouble(raw['logicalWidth'], 1),
                  _readDouble(raw['logicalHeight'], 1),
                ),
              ));
            } finally {
              codec.dispose();
            }
          }
    
          controller.restoreSnapshot(
            strokes: strokes,
            stamps: stamps,
            fills: fills,
            restoredBackgroundColor: Color(_readColor(decoded['backgroundColor'], 0xFFFFFFFF)),
            restoredBrushColor: Color(_readColor(decoded['brushColor'], 0xFFE64A19)),
            restoredBucketColor: Color(_readColor(decoded['bucketColor'], 0xFF80DEEA)),
            restoredStampFillColor: Color(_readColor(decoded['stampFillColor'], 0xFFFFD54F)),
            restoredStampStrokeColor: Color(_readColor(decoded['stampStrokeColor'], 0xFF5D4037)),
            restoredBrushWidth: _readDouble(decoded['brushWidth'], 6),
            restoredBrushStyle: _readEnum(StrokeStyle.values, decoded['brushStyle'], StrokeStyle.solid),
            restoredActiveTool: _readEnum(ActiveTool.values, decoded['activeTool'], ActiveTool.brush),
            restoredSelectedStamp: _readEnum(StampKind.values, decoded['selectedStamp'], StampKind.flower),
            restoredSelectedPage: _readEnum(ColoringPage.values, decoded['selectedPage'], ColoringPage.freeDraw),
          );
          ownershipTransferred = true;
          return true;
        } finally {
          if (!ownershipTransferred) {
            for (final fill in fills) {
              fill.image.dispose();
            }
          }
        }
  }

  List<AdvancedStroke> _decodeStrokes(Object? value) {
    if (value is! List || value.length > _maxStrokes) {
      throw const FormatException('Invalid saved stroke collection.');
    }
    final result = <AdvancedStroke>[];
    var pointCount = 0;
    for (final raw in value) {
      if (raw is! Map<String, dynamic> || raw['points'] is! List) {
        throw const FormatException('Invalid saved stroke.');
      }
      final rawPoints = raw['points'] as List;
      pointCount += rawPoints.length;
      if (pointCount > _maxPoints) {
        throw const FormatException('Saved drawing exceeds point limits.');
      }
      final points = <Offset>[];
      for (final point in rawPoints) {
        if (point is! List || point.length != 2 || point[0] is! num || point[1] is! num) {
          throw const FormatException('Invalid saved stroke point.');
        }
        final x = (point[0] as num).toDouble();
        final y = (point[1] as num).toDouble();
        if (!x.isFinite || !y.isFinite || x.abs() > 100000 || y.abs() > 100000) {
          throw const FormatException('Saved stroke point is outside limits.');
        }
        points.add(Offset(x, y));
      }
      result.add(AdvancedStroke(
        points: points,
        style: _readEnum(StrokeStyle.values, raw['style'], StrokeStyle.solid),
        color: Color(_readColor(raw['color'], 0xFFE64A19)),
        width: _readDouble(raw['width'], 6).clamp(1.0, 48.0).toDouble(),
        order: _readInt(raw['order'], result.length),
      ));
    }
    return result;
  }

  List<CanvasStamp> _decodeStamps(Object? value) {
    if (value is! List || value.length > _maxStamps) {
      throw const FormatException('Invalid saved stamp collection.');
    }
    return value.map((raw) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid saved stamp.');
      }
      return CanvasStamp(
        kind: _readEnum(StampKind.values, raw['kind'], StampKind.flower),
        position: Offset(_readDouble(raw['x'], 0), _readDouble(raw['y'], 0)),
        scale: _readDouble(raw['scale'], 0.72).clamp(0.2, 3.0).toDouble(),
        rotationAngle: _readDouble(raw['rotation'], 0),
        fillColor: Color(_readColor(raw['fillColor'], 0xFFFFD54F)),
        strokeColor: Color(_readColor(raw['strokeColor'], 0xFF5D4037)),
        layerCategory: _readEnum(LayerCategory.values, raw['layerCategory'], LayerCategory.foregroundFlora),
        order: _readInt(raw['order'], 0),
      );
    }).toList(growable: false);
  }

  T _readEnum<T extends Enum>(List<T> values, Object? value, T fallback) {
    if (value is! String) return fallback;
    for (final item in values) {
      if (item.name == value) return item;
    }
    return fallback;
  }

  int _readInt(Object? value, int fallback) => value is int ? value : fallback;

  int _readColor(Object? value, int fallback) {
    final color = _readInt(value, fallback);
    return color.clamp(0, 0xFFFFFFFF).toInt();
  }

  double _readDouble(Object? value, double fallback) {
    final result = value is num ? value.toDouble() : fallback;
    return result.isFinite ? result : fallback;
  }
}
