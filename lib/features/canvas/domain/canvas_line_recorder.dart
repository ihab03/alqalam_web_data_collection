import 'package:flutter/foundation.dart';

/// Single captured point in logical unscaled canvas coordinates per Section 4 & 5.2.
class StrokePoint {
  final double x;
  final double y;
  final int tMs;
  final double p;
  final String kind;

  const StrokePoint({
    required this.x,
    required this.y,
    required this.tMs,
    required this.p,
    required this.kind,
  });

  Map<String, dynamic> toJson() => {
        'x': double.parse(x.toStringAsFixed(2)),
        'y': double.parse(y.toStringAsFixed(2)),
        't_ms': tMs,
        'p': double.parse(p.toStringAsFixed(3)),
        'kind': kind,
      };

  factory StrokePoint.fromJson(Map<String, dynamic> json) {
    return StrokePoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      tMs: (json['t_ms'] as num).toInt(),
      p: (json['p'] as num).toDouble(),
      kind: json['kind'] as String? ?? 'stylus',
    );
  }

  @override
  String toString() => 'StrokePoint(x: $x, y: $y, t: $tMs, p: $p, kind: $kind)';
}

/// In-memory stroke recorder and undo/redo manager for an individual 108px canvas band.
class CanvasLineRecorder extends ChangeNotifier {
  final int lineIndex;
  final List<List<StrokePoint>> strokes = [];
  final List<List<StrokePoint>> redoStack = [];
  List<StrokePoint>? _current;

  CanvasLineRecorder({required this.lineIndex});

  List<StrokePoint>? get currentStroke => _current;

  /// Starts a new stroke at ([x], [y]) with recorded [pressure] and pointer [kind].
  void startStroke(double x, double y, double pressure, String kind) {
    _current = [
      StrokePoint(
        x: x,
        y: y,
        tMs: DateTime.now().millisecondsSinceEpoch,
        p: pressure > 0 ? pressure : 1.0,
        kind: kind,
      ),
    ];
    strokes.add(_current!);
    redoStack.clear();
    notifyListeners();
  }

  /// Appends an intermediate point to the currently active stroke.
  void appendPoint(double x, double y, double pressure, String kind) {
    if (_current == null) return;
    _current!.add(
      StrokePoint(
        x: x,
        y: y,
        tMs: DateTime.now().millisecondsSinceEpoch,
        p: pressure > 0 ? pressure : 1.0,
        kind: kind,
      ),
    );
    notifyListeners();
  }

  /// Finalizes the current stroke.
  void endStroke() {
    _current = null;
    notifyListeners();
  }

  /// Reverts the most recently completed stroke.
  void undo() {
    if (_current != null) {
      strokes.remove(_current);
      _current = null;
      notifyListeners();
      return;
    }
    if (strokes.isNotEmpty) {
      final removed = strokes.removeLast();
      redoStack.add(removed);
      notifyListeners();
    }
  }

  /// Restores the most recently undone stroke.
  void redo() {
    if (redoStack.isNotEmpty) {
      final restored = redoStack.removeLast();
      strokes.add(restored);
      notifyListeners();
    }
  }

  /// Clears all strokes on this canvas band.
  void clear() {
    strokes.clear();
    redoStack.clear();
    _current = null;
    notifyListeners();
  }

  /// Whether this canvas band has at least one valid stroke (>= 2 points).
  bool get hasValidContent {
    return strokes.any((s) => s.length >= 2);
  }

  /// Whether this canvas band is empty.
  bool get isEmpty {
    return strokes.isEmpty || strokes.every((s) => s.length < 2);
  }

  bool get canUndo => strokes.isNotEmpty || _current != null;
  bool get canRedo => redoStack.isNotEmpty;
}
