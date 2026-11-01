import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'drawing_models.dart';

abstract class _DrawingCommand {
  void redo(DrawingController controller);
  void undo(DrawingController controller);

  bool get affectsBackground => false;
  bool get affectsScene => true;
  Iterable<ui.Image> get referencedImages => const <ui.Image>[];
}

class _AddStrokeCommand extends _DrawingCommand {
  _AddStrokeCommand(this.stroke);
  final AdvancedStroke stroke;

  @override
  void redo(DrawingController controller) => controller._strokes.add(stroke);

  @override
  void undo(DrawingController controller) => controller._strokes.remove(stroke);
}

class _AddStampCommand extends _DrawingCommand {
  _AddStampCommand(this.stamp);
  final CanvasStamp stamp;

  @override
  void redo(DrawingController controller) => controller._stamps.add(stamp);

  @override
  void undo(DrawingController controller) => controller._stamps.remove(stamp);
}

class _CompositeCommand extends _DrawingCommand {
  _CompositeCommand(this.commands);

  final List<_DrawingCommand> commands;

  @override
  void redo(DrawingController controller) {
    for (final command in commands) {
      command.redo(controller);
    }
  }

  @override
  void undo(DrawingController controller) {
    for (final command in commands.reversed) {
      command.undo(controller);
    }
  }

  @override
  bool get affectsBackground => commands.any((command) => command.affectsBackground);

  @override
  bool get affectsScene => commands.any((command) => command.affectsScene);

  @override
  Iterable<ui.Image> get referencedImages sync* {
    for (final command in commands) {
      yield* command.referencedImages;
    }
  }
}

class _BackgroundCommand extends _DrawingCommand {
  _BackgroundCommand(this.before, this.after);
  final Color before;
  final Color after;

  @override
  void redo(DrawingController controller) => controller.backgroundColor = after;

  @override
  void undo(DrawingController controller) => controller.backgroundColor = before;

  @override
  bool get affectsBackground => true;

  @override
  bool get affectsScene => false;
}

class _TemplateCommand extends _DrawingCommand {
  _TemplateCommand(this.before, this.after);
  final ColoringPage before;
  final ColoringPage after;

  @override
  void redo(DrawingController controller) => controller.selectedPage = after;

  @override
  void undo(DrawingController controller) => controller.selectedPage = before;

  @override
  bool get affectsBackground => true;

  @override
  bool get affectsScene => false;
}

class _AddFillCommand extends _DrawingCommand {
  _AddFillCommand(this.fill);
  final CanvasFill fill;

  @override
  void redo(DrawingController controller) => controller._fills.add(fill);

  @override
  void undo(DrawingController controller) => controller._fills.remove(fill);

  @override
  bool get affectsBackground => true;

  @override
  bool get affectsScene => false;

  @override
  Iterable<ui.Image> get referencedImages => <ui.Image>[fill.image];
}

class _ClearCommand extends _DrawingCommand {
  _ClearCommand(DrawingController controller)
      : oldStrokes = List<AdvancedStroke>.of(controller._strokes),
        oldStamps = List<CanvasStamp>.of(controller._stamps),
        oldFills = List<CanvasFill>.of(controller._fills);

  final List<AdvancedStroke> oldStrokes;
  final List<CanvasStamp> oldStamps;
  final List<CanvasFill> oldFills;

  @override
  void redo(DrawingController controller) {
    controller._strokes.clear();
    controller._stamps.clear();
    controller._fills.clear();
  }

  @override
  void undo(DrawingController controller) {
    controller._strokes
      ..clear()
      ..addAll(oldStrokes);
    controller._stamps
      ..clear()
      ..addAll(oldStamps);
    controller._fills
      ..clear()
      ..addAll(oldFills);
  }

  @override
  bool get affectsBackground => true;

  @override
  Iterable<ui.Image> get referencedImages =>
      oldFills.map((fill) => fill.image);
}

class DrawingController extends ChangeNotifier {
  static const int maxHistoryEntries = 100;
  static const int maxRasterPixels = 1000000;
  static const int maxFillLayers = 8;

  final List<AdvancedStroke> _strokes = <AdvancedStroke>[];
  final List<CanvasStamp> _stamps = <CanvasStamp>[];
  final List<CanvasFill> _fills = <CanvasFill>[];
  final List<_DrawingCommand> _undoStack = <_DrawingCommand>[];
  final List<_DrawingCommand> _redoStack = <_DrawingCommand>[];
  final Set<ui.Image> _ownedImages = <ui.Image>{};
  final List<DrawingLayer> _layers = <DrawingLayer>[
    const DrawingLayer(id: 1, name: 'Layer 1'),
  ];
  int _nextLayerId = 2;
  int activeLayerId = 1;
  Size canvasSize = Size.zero;
  SymmetryMode symmetryMode = SymmetryMode.none;
  StudioMode studioMode = StudioMode.toddler;

  final ChangeNotifier backgroundRepaint = ChangeNotifier();
  final ChangeNotifier sceneRepaint = ChangeNotifier();
  final ChangeNotifier activeRepaint = ChangeNotifier();

  List<Offset>? _activePoints;
  List<double>? _activePressureSamples;
  Color _activeStrokeColor = const Color(0xFFE64A19);
  double _activeStrokeWidth = 6;
  StrokeStyle _activeStrokeStyle = StrokeStyle.solid;
  int _nextOrder = 0;

  Color backgroundColor = const Color(0xFFFFFFFF);
  Color brushColor = const Color(0xFFE64A19);
  Color bucketColor = const Color(0xFF80DEEA);
  Color stampFillColor = const Color(0xFFFFD54F);
  Color stampStrokeColor = const Color(0xFF5D4037);
  double brushWidth = 6;
  StrokeStyle brushStyle = StrokeStyle.solid;
  ActiveTool activeTool = ActiveTool.brush;
  StampKind selectedStamp = StampKind.flower;
  ColoringPage selectedPage = ColoringPage.freeDraw;

  List<AdvancedStroke> get strokes =>
      UnmodifiableListView<AdvancedStroke>(_strokes);
  List<CanvasStamp> get stamps =>
      UnmodifiableListView<CanvasStamp>(_stamps);
  List<CanvasFill> get fills => UnmodifiableListView<CanvasFill>(_fills);
  List<DrawingLayer> get layers => UnmodifiableListView<DrawingLayer>(_layers);
  DrawingLayer get activeLayer =>
      _layers.firstWhere((layer) => layer.id == activeLayerId);
  List<Offset> get activePoints =>
      UnmodifiableListView<Offset>(_activePoints ?? const <Offset>[]);
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get hasActiveStroke => _activePoints != null;
  Color get activeStrokeColor => _activeStrokeColor;
  double get activeStrokeWidth => _activeStrokeWidth;
  StrokeStyle get activeStrokeStyle => _activeStrokeStyle;

  void setActiveTool(ActiveTool value) {
    if (activeTool == value) return;
    activeTool = value;
    notifyListeners();
  }

  void setBrushColor(Color value) {
    if (brushColor == value) return;
    brushColor = value;
    notifyListeners();
  }

  void setBucketColor(Color value) {
    if (bucketColor == value) return;
    bucketColor = value;
    notifyListeners();
  }

  void setStampColors({Color? fill, Color? stroke}) {
    if (fill != null) stampFillColor = fill;
    if (stroke != null) stampStrokeColor = stroke;
    notifyListeners();
  }

  void setBrushStyle(StrokeStyle value) {
    if (brushStyle == value) return;
    brushStyle = value;
    notifyListeners();
  }

  void setBrushWidth(double value) {
    final next = value.clamp(1.0, 32.0).toDouble();
    if (brushWidth == next) return;
    brushWidth = next;
    notifyListeners();
  }

  void setSelectedStamp(StampKind value) {
    if (selectedStamp == value) return;
    selectedStamp = value;
    notifyListeners();
  }


  void setCanvasSize(Size value) {
    if (canvasSize == value) return;
    canvasSize = value;
  }

  void setStudioMode(StudioMode value) {
    if (studioMode == value) return;
    studioMode = value;
    notifyListeners();
  }

  void setSymmetryMode(SymmetryMode value) {
    if (symmetryMode == value) return;
    symmetryMode = value;
    notifyListeners();
  }

  int? addLayer({String? name}) {
    if (_layers.length >= 12) return null;
    final id = _nextLayerId++;
    _layers.add(DrawingLayer(
      id: id,
      name: name ?? 'Layer ${_layers.length + 1}',
    ));
    activeLayerId = id;
    _clearHistory();
    _notifyLayerChange();
    return id;
  }

  bool selectLayer(int id) {
    if (!_layers.any((layer) => layer.id == id)) return false;
    if (activeLayerId == id) return true;
    activeLayerId = id;
    notifyListeners();
    return true;
  }

  bool setLayerVisibility(int id, bool visible) {
    final index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) return false;
    _layers[index] = _layers[index].copyWith(visible: visible);
    _notifyLayerChange();
    return true;
  }

  bool setLayerOpacity(int id, double opacity) {
    final index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0 || !opacity.isFinite) return false;
    _layers[index] = _layers[index].copyWith(opacity: opacity);
    _notifyLayerChange();
    return true;
  }

  bool renameLayer(int id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 32) return false;
    final index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) return false;
    _layers[index] = _layers[index].copyWith(name: trimmed);
    notifyListeners();
    return true;
  }

  bool removeLayer(int id) {
    if (_layers.length <= 1) return false;
    final index = _layers.indexWhere((layer) => layer.id == id);
    if (index < 0) return false;
    _layers.removeAt(index);
    _strokes.removeWhere((stroke) => stroke.layerId == id);
    _stamps.removeWhere((stamp) => stamp.layerId == id);
    _fills.removeWhere((fill) => fill.layerId == id);
    if (activeLayerId == id) activeLayerId = _layers.last.id;
    _clearHistory();
    _notifyLayerChange();
    return true;
  }

  bool mergeLayerDown(int id) {
    final index = _layers.indexWhere((layer) => layer.id == id);
    if (index <= 0) return false;
    final source = _layers[index];
    final target = _layers[index - 1];
    for (var i = 0; i < _strokes.length; i++) {
      final stroke = _strokes[i];
      if (stroke.layerId == source.id) {
        _strokes[i] = AdvancedStroke(
          points: stroke.points,
          style: stroke.style,
          color: stroke.color,
          width: stroke.width,
          order: stroke.order,
          layerId: target.id,
          pressureSamples: stroke.pressureSamples,
          createdAt: stroke.createdAt,
        );
      }
    }
    for (var i = 0; i < _stamps.length; i++) {
      final stamp = _stamps[i];
      if (stamp.layerId == source.id) {
        _stamps[i] = CanvasStamp(
          kind: stamp.kind,
          position: stamp.position,
          scale: stamp.scale,
          rotationAngle: stamp.rotationAngle,
          fillColor: stamp.fillColor,
          strokeColor: stamp.strokeColor,
          layerCategory: stamp.layerCategory,
          order: stamp.order,
          layerId: target.id,
        );
      }
    }
    for (var i = 0; i < _fills.length; i++) {
      final fill = _fills[i];
      if (fill.layerId == source.id) {
        _fills[i] = CanvasFill(
          image: fill.image,
          logicalSize: fill.logicalSize,
          layerId: target.id,
        );
      }
    }
    _layers.removeAt(index);
    if (activeLayerId == id) activeLayerId = target.id;
    _clearHistory();
    _notifyLayerChange();
    return true;
  }

  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _pruneOwnedImages();
  }

  void _notifyLayerChange() {
    notifyListeners();
    backgroundRepaint.notifyListeners();
    sceneRepaint.notifyListeners();
    activeRepaint.notifyListeners();
  }

  List<List<Offset>> _symmetryPaths(List<Offset> points) {
    final mode = symmetryMode;
    if (mode == SymmetryMode.none || canvasSize.isEmpty) return <List<Offset>>[points];
    final center = canvasSize.center(Offset.zero);
    Offset mirror(Offset point, {bool horizontal = false, bool vertical = false}) {
      return Offset(
        horizontal ? 2 * center.dx - point.dx : point.dx,
        vertical ? 2 * center.dy - point.dy : point.dy,
      );
    }
    if (mode == SymmetryMode.mirrorHorizontal) {
      return <List<Offset>>[
        points,
        points.map((point) => mirror(point, horizontal: true)).toList(growable: false),
      ];
    }
    if (mode == SymmetryMode.mirrorVertical) {
      return <List<Offset>>[
        points,
        points.map((point) => mirror(point, vertical: true)).toList(growable: false),
      ];
    }
    final count = mode == SymmetryMode.radial4 ? 4 : 8;
    return List<List<Offset>>.generate(count, (index) {
      final angle = index * 2 * 3.141592653589793 / count;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      return points.map((point) {
        final dx = point.dx - center.dx;
        final dy = point.dy - center.dy;
        return Offset(
          center.dx + dx * cosA - dy * sinA,
          center.dy + dx * sinA + dy * cosA,
        );
      }).toList(growable: false);
    }, growable: false);
  }

  void _commitStroke(List<Offset> points, {
    required StrokeStyle style,
    required Color color,
    required double width,
    List<double>? pressureSamples,
  }) {
    final paths = _symmetryPaths(points);
    final commands = <_DrawingCommand>[];
    for (final path in paths) {
      commands.add(_AddStrokeCommand(AdvancedStroke(
        points: path,
        style: style,
        color: color,
        width: width,
        order: _nextOrder++,
        layerId: activeLayerId,
        pressureSamples: pressureSamples,
      )));
    }
    if (commands.length == 1) {
      _execute(commands.single);
    } else if (commands.isNotEmpty) {
      _execute(_CompositeCommand(commands));
    }
  }

  void beginStroke(Offset point, {double pressure = 1}) {
    if (activeTool != ActiveTool.brush) return;
    _activePoints = <Offset>[point];
    _activePressureSamples = <double>[_normalisePressure(pressure)];
    _activeStrokeColor = brushColor;
    _activeStrokeWidth = brushWidth;
    _activeStrokeStyle = brushStyle;
    activeRepaint.notifyListeners();
  }

  double _normalisePressure(double pressure) =>
      pressure.isFinite ? pressure.clamp(0.1, 1.0).toDouble() : 1.0;

  void appendActivePoint(Offset point, {double pressure = 1}) {
    final active = _activePoints;
    if (active == null || active.isEmpty) return;
    if ((active.last - point).distance < 0.55) return;
    active.add(point);
    _activePressureSamples?.add(_normalisePressure(pressure));
    activeRepaint.notifyListeners();
  }

  void finishStroke() {
    final active = _activePoints;
    final pressureSamples = _activePressureSamples;
    if (active == null) return;
    _activePoints = null;
    _activePressureSamples = null;
    if (active.isNotEmpty) {
      _commitStroke(
        active,
        style: _activeStrokeStyle,
        color: _activeStrokeColor,
        width: _activeStrokeWidth,
        pressureSamples: pressureSamples,
      );
    } else {
      activeRepaint.notifyListeners();
    }
  }

  void cancelActiveStroke({bool keepPartialDrawing = true}) {
    final active = _activePoints;
    final pressureSamples = _activePressureSamples;
    _activePoints = null;
    _activePressureSamples = null;
    if (keepPartialDrawing && active != null && active.isNotEmpty) {
      _commitStroke(
        active,
        style: _activeStrokeStyle,
        color: _activeStrokeColor,
        width: _activeStrokeWidth,
        pressureSamples: pressureSamples,
      );
    } else {
      activeRepaint.notifyListeners();
    }
  }

  void addStamp(Offset position) {
    final kind = selectedStamp;
    final category = switch (kind) {
      StampKind.pond => LayerCategory.sceneryPond,
      StampKind.house => LayerCategory.architectureHouse,
      StampKind.flower || StampKind.fish => LayerCategory.foregroundFlora,
    };
    _execute(_AddStampCommand(CanvasStamp(
      kind: kind,
      position: position,
      scale: 0.72,
      rotationAngle: 0,
      fillColor: stampFillColor,
      strokeColor: stampStrokeColor,
      layerCategory: category,
      order: _nextOrder++,
      layerId: activeLayerId,
    )));
  }

  void setBackgroundColor(Color value) {
    if (backgroundColor == value) return;
    _execute(_BackgroundCommand(backgroundColor, value));
  }

  void setSelectedPage(ColoringPage value) {
    if (selectedPage == value) return;
    _execute(_TemplateCommand(selectedPage, value));
  }

  bool addFillImage(ui.Image image, Size logicalSize) {
    if (_fills.length >= maxFillLayers || _ownedImages.length >= maxFillLayers ||
        logicalSize.width <= 0 ||
        logicalSize.height <= 0) {
      return false;
    }
    final fill = CanvasFill(
      image: image,
      logicalSize: logicalSize,
      layerId: activeLayerId,
    );
    _ownedImages.add(image);
    _execute(_AddFillCommand(fill));
    return true;
  }

  void clearCanvas() {
    if (_strokes.isEmpty && _stamps.isEmpty && _fills.isEmpty) return;
    _execute(_ClearCommand(this));
  }

  bool undo() {
    if (_undoStack.isEmpty) return false;
    final command = _undoStack.removeLast();
    command.undo(this);
    _redoStack.add(command);
    _pruneOwnedImages();
    _notifyForCommand(command);
    return true;
  }

  bool redo() {
    if (_redoStack.isEmpty) return false;
    final command = _redoStack.removeLast();
    command.redo(this);
    _undoStack.add(command);
    _pruneOwnedImages();
    _notifyForCommand(command);
    return true;
  }

  void _execute(_DrawingCommand command) {
    command.redo(this);
    _undoStack.add(command);
    _redoStack.clear();
    if (_undoStack.length > maxHistoryEntries) {
      _undoStack.removeAt(0);
    }
    _pruneOwnedImages();
    _notifyForCommand(command);
  }

  void _notifyForCommand(_DrawingCommand command) {
    notifyListeners();
    if (command.affectsBackground) backgroundRepaint.notifyListeners();
    if (command.affectsScene) sceneRepaint.notifyListeners();
    // A committed stroke must clear the temporary active-stroke layer.
    activeRepaint.notifyListeners();
  }

  void _pruneOwnedImages() {
    final referenced = <ui.Image>{};
    for (final fill in _fills) {
      referenced.add(fill.image);
    }
    for (final command in <_DrawingCommand>[..._undoStack, ..._redoStack]) {
      referenced.addAll(command.referencedImages);
    }
    for (final image in List<ui.Image>.of(_ownedImages)) {
      if (!referenced.contains(image)) {
        image.dispose();
        _ownedImages.remove(image);
      }
    }
  }


  /// Loads a validated local snapshot as this session's baseline.
  /// Previous-session edits are preserved; this session starts with fresh
  /// undo/redo stacks so the app never fabricates unavailable command history.
  void restoreSnapshot({
    required Iterable<AdvancedStroke> strokes,
    required Iterable<CanvasStamp> stamps,
    required Iterable<CanvasFill> fills,
    required Color restoredBackgroundColor,
    required Color restoredBrushColor,
    required Color restoredBucketColor,
    required Color restoredStampFillColor,
    required Color restoredStampStrokeColor,
    required double restoredBrushWidth,
    required StrokeStyle restoredBrushStyle,
    required ActiveTool restoredActiveTool,
    required StampKind restoredSelectedStamp,
    required ColoringPage restoredSelectedPage,
    List<DrawingLayer>? restoredLayers,
    int? restoredActiveLayerId,
    SymmetryMode restoredSymmetryMode = SymmetryMode.none,
    StudioMode restoredStudioMode = StudioMode.toddler,
  }) {
    for (final image in _ownedImages) {
      image.dispose();
    }
    _ownedImages.clear();
    _strokes
      ..clear()
      ..addAll(strokes);
    _stamps
      ..clear()
      ..addAll(stamps);
    _fills
      ..clear()
      ..addAll(fills);
    _ownedImages.addAll(_fills.map((fill) => fill.image));

    backgroundColor = restoredBackgroundColor;
    brushColor = restoredBrushColor;
    bucketColor = restoredBucketColor;
    stampFillColor = restoredStampFillColor;
    stampStrokeColor = restoredStampStrokeColor;
    brushWidth = restoredBrushWidth.clamp(1.0, 32.0).toDouble();
    brushStyle = restoredBrushStyle;
    activeTool = restoredActiveTool;
    selectedStamp = restoredSelectedStamp;
    selectedPage = restoredSelectedPage;
    _layers
      ..clear()
      ..addAll(restoredLayers == null || restoredLayers.isEmpty
          ? const <DrawingLayer>[DrawingLayer(id: 1, name: 'Layer 1')]
          : restoredLayers);
    activeLayerId = _layers.any((layer) => layer.id == restoredActiveLayerId)
        ? restoredActiveLayerId!
        : _layers.first.id;
    _nextLayerId = _layers.fold<int>(1, (maximum, layer) =>
        layer.id >= maximum ? layer.id + 1 : maximum);
    symmetryMode = restoredSymmetryMode;
    studioMode = restoredStudioMode;
    _activePoints = null;
    _activePressureSamples = null;
    _undoStack.clear();
    _redoStack.clear();

    var nextOrder = 0;
    for (final stroke in _strokes) {
      if (stroke.order >= nextOrder) nextOrder = stroke.order + 1;
    }
    for (final stamp in _stamps) {
      if (stamp.order >= nextOrder) nextOrder = stamp.order + 1;
    }
    _nextOrder = nextOrder;

    notifyListeners();
    backgroundRepaint.notifyListeners();
    sceneRepaint.notifyListeners();
    activeRepaint.notifyListeners();
  }

  @override
  void dispose() {
    for (final image in _ownedImages) {
      image.dispose();
    }
    _ownedImages.clear();
    backgroundRepaint.dispose();
    sceneRepaint.dispose();
    activeRepaint.dispose();
    super.dispose();
  }
}
