import 'dart:collection';
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

  final ChangeNotifier backgroundRepaint = ChangeNotifier();
  final ChangeNotifier sceneRepaint = ChangeNotifier();
  final ChangeNotifier activeRepaint = ChangeNotifier();

  List<Offset>? _activePoints;
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

  void beginStroke(Offset point) {
    if (activeTool != ActiveTool.brush) return;
    _activePoints = <Offset>[point];
    _activeStrokeColor = brushColor;
    _activeStrokeWidth = brushWidth;
    _activeStrokeStyle = brushStyle;
    activeRepaint.notifyListeners();
  }

  void appendActivePoint(Offset point) {
    final active = _activePoints;
    if (active == null || active.isEmpty) return;
    if ((active.last - point).distance < 0.55) return;
    active.add(point);
    activeRepaint.notifyListeners();
  }

  void finishStroke() {
    final active = _activePoints;
    if (active == null) return;
    _activePoints = null;
    if (active.isNotEmpty) {
      _execute(_AddStrokeCommand(AdvancedStroke(
        points: active,
        style: _activeStrokeStyle,
        color: _activeStrokeColor,
        width: _activeStrokeWidth,
        order: _nextOrder++,
      )));
    } else {
      activeRepaint.notifyListeners();
    }
  }

  void cancelActiveStroke({bool keepPartialDrawing = true}) {
    final active = _activePoints;
    _activePoints = null;
    if (keepPartialDrawing && active != null && active.isNotEmpty) {
      _execute(_AddStrokeCommand(AdvancedStroke(
        points: active,
        style: brushStyle,
        color: brushColor,
        width: brushWidth,
        order: _nextOrder++,
      )));
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
    final fill = CanvasFill(image: image, logicalSize: logicalSize);
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
