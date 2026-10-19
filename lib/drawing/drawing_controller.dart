import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drawing_models.dart';

/// Authoritative document state. Drawing updates notify the canvas painter
/// directly instead of forcing unrelated UI widgets to rebuild.
class DrawingController extends ChangeNotifier {
  DrawingController({this.persistenceEnabled = true});

  static const _storageKey = 'vibesync_drawing_document_v1';
  static const maxHistoryEntries = 100;

  final bool persistenceEnabled;
  final List<AdvancedStroke> _strokes = [];
  final List<CanvasStamp> _stamps = [];
  final List<Offset> _activePoints = [];
  final List<DrawingSnapshot> _undo = [];
  final List<DrawingSnapshot> _redo = [];

  late final List<AdvancedStroke> strokes = UnmodifiableListView(_strokes);
  late final List<CanvasStamp> stamps = UnmodifiableListView(_stamps);

  Color _backgroundColor = Colors.white;
  Color _brushColor = Colors.deepOrange;
  Color _bucketColor = Colors.amber;
  Color _stampFillColor = Colors.amber;
  Color _stampStrokeColor = Colors.brown;
  double _brushWidth = 6;
  StrokeStyle _brushStyle = StrokeStyle.solid;
  ActiveTool _activeTool = ActiveTool.brush;
  StampKind _selectedStamp = StampKind.flower;
  Color _activeStrokeColor = Colors.deepOrange;
  StrokeStyle _activeStrokeStyle = StrokeStyle.solid;
  double _activeStrokeWidth = 6;
  bool _isDrawing = false;
  bool _disposed = false;
  int _revision = 0;
  int _documentRevision = 0;
  int _nextStampOrder = 0;
  Timer? _persistTimer;
  SharedPreferences? _prefs;

  int get revision => _revision;
  Color get backgroundColor => _backgroundColor;
  Color get brushColor => _brushColor;
  Color get bucketColor => _bucketColor;
  Color get stampFillColor => _stampFillColor;
  Color get stampStrokeColor => _stampStrokeColor;
  double get brushWidth => _brushWidth;
  StrokeStyle get brushStyle => _brushStyle;
  ActiveTool get activeTool => _activeTool;
  StampKind get selectedStamp => _selectedStamp;
  bool get isDrawing => _isDrawing;
  List<Offset> get activePoints => _activePoints;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void selectTool(ActiveTool value) {
    if (_activeTool == value) return;
    _activeTool = value;
    _notify(persist: false);
  }

  void selectBrushColor(Color value) {
    if (_brushColor == value) return;
    _brushColor = value;
    _notify(persist: false);
  }

  void selectBucketColor(Color value) {
    if (_bucketColor == value) return;
    _bucketColor = value;
    _notify(persist: false);
  }

  void selectStampColors({Color? fill, Color? outline}) {
    var changed = false;
    if (fill != null && fill != _stampFillColor) {
      _stampFillColor = fill;
      changed = true;
    }
    if (outline != null && outline != _stampStrokeColor) {
      _stampStrokeColor = outline;
      changed = true;
    }
    if (changed) _notify(persist: false);
  }

  void selectBrushStyle(StrokeStyle value) {
    if (_brushStyle == value) return;
    _brushStyle = value;
    _notify(persist: false);
  }

  void selectBrushWidth(double value) {
    final safeWidth = value.clamp(1.0, 40.0).toDouble();
    if (_brushWidth == safeWidth) return;
    _brushWidth = safeWidth;
    _notify(persist: false);
  }

  void selectStamp(StampKind value) {
    _selectedStamp = value;
    _activeTool = ActiveTool.stamp;
    _notify(persist: false);
  }

  void beginStroke(Offset point) {
    if (_activeTool != ActiveTool.brush || _isDrawing) return;
    _isDrawing = true;
    _activePoints..clear()..add(point);
    _activeStrokeColor = _brushColor;
    _activeStrokeStyle = _brushStyle;
    _activeStrokeWidth = _brushWidth;
    _notify(persist: false);
  }

  void extendStroke(Offset point) {
    if (!_isDrawing) return;
    if (_activePoints.isNotEmpty && (_activePoints.last - point).distance < 0.5) return;
    _activePoints.add(point);
    _notify(persist: false);
  }

  void endStroke() {
    if (!_isDrawing) return;
    _isDrawing = false;
    if (_activePoints.isEmpty) {
      _notify(persist: false);
      return;
    }
    final stroke = AdvancedStroke(
      points: List<Offset>.from(_activePoints),
      style: _activeStrokeStyle,
      color: _activeStrokeColor,
      width: _activeStrokeWidth,
    );
    _activePoints.clear();
    _pushUndoSnapshot();
    _strokes.add(stroke);
    _documentRevision++;
    _notify();
  }

  void cancelStroke({bool keepPartialStroke = true}) {
    if (!_isDrawing) return;
    if (keepPartialStroke) {
      endStroke();
    } else {
      _isDrawing = false;
      _activePoints.clear();
      _notify(persist: false);
    }
  }

  void placeSelectedStamp(Offset position) {
    final stamp = CanvasStamp(
      id: 'stamp-' + DateTime.now().microsecondsSinceEpoch.toString() + '-' + _nextStampOrder.toString(),
      kind: _selectedStamp,
      position: position,
      scale: 1,
      rotationAngle: 0,
      fillColor: _stampFillColor,
      strokeColor: _stampStrokeColor,
      layerCategory: _selectedStamp.defaultLayer,
      order: _nextStampOrder++,
    );
    _pushUndoSnapshot();
    _stamps.add(stamp);
    _documentRevision++;
    _notify();
  }

  void setBackgroundColor(Color value) {
    if (_backgroundColor == value) return;
    _pushUndoSnapshot();
    _backgroundColor = value;
    _documentRevision++;
    _notify();
  }

  void clearCanvas() {
    if (_strokes.isEmpty && _stamps.isEmpty) return;
    _pushUndoSnapshot();
    _strokes.clear();
    _stamps.clear();
    _activePoints.clear();
    _isDrawing = false;
    _documentRevision++;
    _notify();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_capture());
    _restoreSnapshot(_undo.removeLast());
    _documentRevision++;
    _notify();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_capture());
    _trimHistory(_undo);
    _restoreSnapshot(_redo.removeLast());
    _documentRevision++;
    _notify();
  }

  DrawingSnapshot _capture() => DrawingSnapshot(
        strokes: List<AdvancedStroke>.unmodifiable(_strokes),
        stamps: List<CanvasStamp>.unmodifiable(_stamps),
        backgroundColor: _backgroundColor,
      );

  void _restoreSnapshot(DrawingSnapshot state) {
    _strokes..clear()..addAll(state.strokes);
    _stamps..clear()..addAll(state.stamps);
    _backgroundColor = state.backgroundColor;
    _activePoints.clear();
    _isDrawing = false;
    _nextStampOrder = _stamps.fold<int>(
      0,
      (maxOrder, stamp) => stamp.order >= maxOrder ? stamp.order + 1 : maxOrder,
    );
  }

  void _pushUndoSnapshot() {
    _undo.add(_capture());
    _trimHistory(_undo);
    _redo.clear();
  }

  void _trimHistory(List<DrawingSnapshot> stack) {
    if (stack.length > maxHistoryEntries) {
      stack.removeRange(0, stack.length - maxHistoryEntries);
    }
  }

  void _notify({bool persist = true}) {
    if (_disposed) return;
    _revision++;
    notifyListeners();
    if (persist) _schedulePersist();
  }

  /// Persist drawings on-device only. If the user starts drawing before the
  /// asynchronous restore finishes, the new drawing always takes precedence.
  Future<void> restore() async {
    if (!persistenceEnabled) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final encoded = _prefs!.getString(_storageKey);
      if (encoded == null || encoded.isEmpty) return;
      if (_documentRevision != 0 || _strokes.isNotEmpty || _stamps.isNotEmpty) return;
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic> || data['version'] != 1) return;
      final loadedStrokes = <AdvancedStroke>[];
      final loadedStamps = <CanvasStamp>[];
      final rawStrokes = data['strokes'];
      final rawStamps = data['stamps'];
      if (rawStrokes is List) {
        for (final raw in rawStrokes) {
          if (raw is Map<String, dynamic>) {
            final item = AdvancedStroke.fromJson(raw);
            if (item.points.isNotEmpty) loadedStrokes.add(item);
          }
        }
      }
      if (rawStamps is List) {
        for (final raw in rawStamps) {
          if (raw is Map<String, dynamic>) loadedStamps.add(CanvasStamp.fromJson(raw));
        }
      }
      _strokes.addAll(loadedStrokes);
      _stamps.addAll(loadedStamps);
      if (data['background'] is num) {
        _backgroundColor = Color((data['background'] as num).toInt());
      }
      _nextStampOrder = _stamps.fold<int>(
        0,
        (maxOrder, stamp) => stamp.order >= maxOrder ? stamp.order + 1 : maxOrder,
      );
      _notify(persist: false);
    } catch (error) {
      debugPrint('Drawing restore skipped: $error');
    }
  }

  void _schedulePersist() {
    if (!persistenceEnabled || _disposed) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 450), _persistDocument);
  }

  Future<void> _persistDocument() async {
    if (!persistenceEnabled || _disposed) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'version': 1,
        'background': _backgroundColor.value,
        'strokes': _strokes.map((s) => s.toJson()).toList(),
        'stamps': _stamps.map((s) => s.toJson()).toList(),
      });
      await _prefs!.setString(_storageKey, payload);
    } catch (error) {
      debugPrint('Drawing auto-save skipped: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _persistTimer?.cancel();
    super.dispose();
  }
}