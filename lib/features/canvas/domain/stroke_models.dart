import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Represents a single pointer point captured on the handwriting canvas.
class StrokePoint {
  /// The x-coordinate in logical pixels.
  final double dx;

  /// The y-coordinate in logical pixels.
  final double dy;

  /// The stylus pressure normalized between 0.0 and 1.0 (defaults to 1.0 for non-stylus touches).
  final double pressure;

  /// Epoch timestamp in milliseconds when this point was recorded.
  final int timestampMs;

  const StrokePoint({
    required this.dx,
    required this.dy,
    this.pressure = 1.0,
    required this.timestampMs,
  });

  StrokePoint copyWith({
    double? dx,
    double? dy,
    double? pressure,
    int? timestampMs,
  }) {
    return StrokePoint(
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      pressure: pressure ?? this.pressure,
      timestampMs: timestampMs ?? this.timestampMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrokePoint &&
          runtimeType == other.runtimeType &&
          dx == other.dx &&
          dy == other.dy &&
          pressure == other.pressure &&
          timestampMs == other.timestampMs;

  @override
  int get hashCode => Object.hash(dx, dy, pressure, timestampMs);

  @override
  String toString() =>
      'StrokePoint(dx: $dx, dy: $dy, pressure: $pressure, time: $timestampMs)';
}

/// Rich Arabic pen calligraphy and writing styles.
enum PenStyle {
  /// قلم خط عربي: Calligraphic chisel nib (authentic thick-and-thin Arabic calligraphy based on 35° angle).
  arabicQalam,

  /// قلم حبر سائل: Dynamic velocity/pressure ink.
  fountainPen,

  /// قلم جاف ثابت: Rock-solid uniform pen with 100% constant width.
  monolinePen,

  /// قلم تحديد: Chisel marker (translucent 0.30 alpha broad flat stroke with StrokeCap.square).
  highlighter,

  /// قلم عريض: Bold uniform stroke width (alias/legacy).
  smoothMarker,
}

extension PenStyleX on PenStyle {
  String get labelArabic {
    switch (this) {
      case PenStyle.arabicQalam:
        return 'خط عربي';
      case PenStyle.fountainPen:
        return 'حبر سائل';
      case PenStyle.monolinePen:
        return 'قلم ثابت';
      case PenStyle.highlighter:
        return 'تحديد';
      case PenStyle.smoothMarker:
        return 'عريض';
    }
  }
}

/// Selectable eraser behaviors.
enum EraserMode {
  /// ممحاة الخط الكامل: Swiping or touching any existing stroke deletes it immediately in real-time.
  strokeEraser,

  /// ممحاة دقيقة: Precision pixel eraser committing BlendMode.clear path.
  pixelEraser,
}

extension EraserModeX on EraserMode {
  String get labelArabic {
    switch (this) {
      case EraserMode.strokeEraser:
        return 'ممحاة الخط الكامل';
      case EraserMode.pixelEraser:
        return 'ممحاة دقيقة';
    }
  }
}

/// Preset ink palette colors for the handwriting slate.
abstract class CanvasColors {
  /// Deep Slate (#0F172A)
  static const Color deepSlate = Color(0xFF0F172A);

  /// Deep Emerald (#265C4B)
  static const Color deepEmerald = Color(0xFF265C4B);

  /// Warm Gold (#8B9758)
  static const Color warmGold = Color(0xFF8B9758);

  /// Royal Navy (#1E3A8A)
  static const Color royalNavy = Color(0xFF1E3A8A);

  /// Burgundy (#991B1B)
  static const Color burgundy = Color(0xFF991B1B);

  /// Pure White / Mint (#F8FAFC)
  static const Color pureWhiteMint = Color(0xFFF8FAFC);

  // Backward-compatibility aliases
  static const Color charcoalBlack = deepSlate;
  static const Color darkNavy = royalNavy;
  static const Color crimson = burgundy;

  static const List<Color> presetColors = [
    deepSlate,
    deepEmerald,
    warmGold,
    royalNavy,
    burgundy,
    pureWhiteMint,
  ];
}

/// Represents a continuous line/path drawn by the learner with pen or eraser.
class HandwritingStroke {
  /// The ordered sequence of [StrokePoint]s comprising this stroke (smoothed for rendering).
  final List<StrokePoint> points;

  /// The raw unsmoothed CSS coordinates (x, y, p, t) preserved strictly for Section 4 ML export.
  final List<StrokePoint>? rawPoints;

  /// Whether this stroke acts as an erasing mask.
  final bool isEraser;

  /// Visual stroke thickness in logical pixels (default 7.0 for bold legibility).
  final double strokeWidth;

  /// The artistic nib style used when drawing this stroke.
  final PenStyle penStyle;

  /// The ink color of this stroke.
  final Color color;

  /// Pre-built and cached [Path] for zero-latency 120fps GPU canvas drawing.
  final Path? cachedPath;

  const HandwritingStroke({
    required this.points,
    this.rawPoints,
    this.isEraser = false,
    this.strokeWidth = 7.0,
    this.penStyle = PenStyle.monolinePen,
    this.color = CanvasColors.deepSlate,
    this.cachedPath,
  });

  /// Returns raw points if present, falling back to smoothed points.
  List<StrokePoint> get effectiveRawPoints => rawPoints ?? points;

  /// Returns the pre-cached [Path] or lazily builds it.
  Path get path => cachedPath ?? buildPath();

  /// Constructs a geometry-accurate [Path] across [points] matching the [penStyle].
  Path buildPath() {
    final p = Path();
    if (points.isEmpty) return p;

    if (points.length == 1) {
      p.addOval(Rect.fromCircle(
        center: Offset(points[0].dx, points[0].dy),
        radius: strokeWidth / 2,
      ));
      return p;
    }

    if (penStyle == PenStyle.arabicQalam && !isEraser) {
      return _buildCalligraphicRibbonPath(points, strokeWidth, angleDegrees: 35.0);
    }

    if (penStyle == PenStyle.fountainPen && !isEraser) {
      return _buildFountainRibbonPath(points, strokeWidth);
    }

    if (points.length == 2) {
      p.moveTo(points[0].dx, points[0].dy);
      p.lineTo(points[1].dx, points[1].dy);
      return p;
    }

    p.moveTo(points[0].dx, points[0].dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = Offset(points[i].dx, points[i].dy);
      final p1 = Offset(points[i + 1].dx, points[i + 1].dy);
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      p.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    p.lineTo(points.last.dx, points.last.dy);
    return p;
  }

  /// Builds a calligraphic 35° chisel ribbon polygon path for Arabic calligraphy.
  static Path _buildCalligraphicRibbonPath(
    List<StrokePoint> pts,
    double width, {
    double angleDegrees = 35.0,
  }) {
    final path = Path();
    if (pts.isEmpty) return path;

    final rad = angleDegrees * math.pi / 180.0;
    // Chisel nib offset vector centered at origin
    final halfW = width / 2.0;
    final nx = halfW * math.cos(rad);
    final ny = -halfW * math.sin(rad);

    if (pts.length == 1) {
      final c = Offset(pts[0].dx, pts[0].dy);
      path.moveTo(c.dx - nx, c.dy - ny);
      path.lineTo(c.dx + nx, c.dy + ny);
      path.lineTo(c.dx + nx + 1, c.dy + ny + 1);
      path.lineTo(c.dx - nx + 1, c.dy - ny + 1);
      path.close();
      return path;
    }

    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = Offset(pts[i].dx, pts[i].dy);
      final p1 = Offset(pts[i + 1].dx, pts[i + 1].dy);

      final a0 = Offset(p0.dx + nx, p0.dy + ny);
      final b0 = Offset(p0.dx - nx, p0.dy - ny);
      final a1 = Offset(p1.dx + nx, p1.dy + ny);
      final b1 = Offset(p1.dx - nx, p1.dy - ny);

      final quad = Path()
        ..moveTo(a0.dx, a0.dy)
        ..lineTo(a1.dx, a1.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b0.dx, b0.dy)
        ..close();
      path.addPath(quad, Offset.zero);
    }

    return path;
  }

  /// Builds a dynamic velocity/pressure responsive ribbon path for fountain pen.
  static Path _buildFountainRibbonPath(List<StrokePoint> pts, double baseWidth) {
    final path = Path();
    if (pts.isEmpty) return path;

    if (pts.length == 1) {
      path.addOval(Rect.fromCircle(
        center: Offset(pts[0].dx, pts[0].dy),
        radius: (baseWidth / 7.0) * 1.5,
      ));
      return path;
    }

    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final segDir = Offset(p1.dx - p0.dx, p1.dy - p0.dy);
      final segLen = segDir.distance;

      if (segLen > 0.001) {
        final norm = Offset(-segDir.dy / segLen, segDir.dx / segLen);
        final pScale0 = (p0.pressure > 0 ? p0.pressure : 0.5).clamp(0.2, 1.2);
        final pScale1 = (p1.pressure > 0 ? p1.pressure : 0.5).clamp(0.2, 1.2);
        final w0 = (1.5 + 2.0 * pScale0) * (baseWidth / 7.0);
        final w1 = (1.5 + 2.0 * pScale1) * (baseWidth / 7.0);

        final a0 = Offset(p0.dx + norm.dx * (w0 / 2), p0.dy + norm.dy * (w0 / 2));
        final b0 = Offset(p0.dx - norm.dx * (w0 / 2), p0.dy - norm.dy * (w0 / 2));
        final a1 = Offset(p1.dx + norm.dx * (w1 / 2), p1.dy + norm.dy * (w1 / 2));
        final b1 = Offset(p1.dx - norm.dx * (w1 / 2), p1.dy - norm.dy * (w1 / 2));

        final quad = Path()
          ..moveTo(a0.dx, a0.dy)
          ..lineTo(a1.dx, a1.dy)
          ..lineTo(b1.dx, b1.dy)
          ..lineTo(b0.dx, b0.dy)
          ..close();
        quad.addOval(Rect.fromCircle(center: Offset(p1.dx, p1.dy), radius: w1 / 2));
        path.addPath(quad, Offset.zero);
      }
    }

    return path;
  }

  HandwritingStroke copyWith({
    List<StrokePoint>? points,
    List<StrokePoint>? rawPoints,
    bool? isEraser,
    double? strokeWidth,
    PenStyle? penStyle,
    Color? color,
    Path? cachedPath,
  }) {
    return HandwritingStroke(
      points: points ?? this.points,
      rawPoints: rawPoints ?? this.rawPoints,
      isEraser: isEraser ?? this.isEraser,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      penStyle: penStyle ?? this.penStyle,
      color: color ?? this.color,
      cachedPath: cachedPath ?? this.cachedPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HandwritingStroke &&
          runtimeType == other.runtimeType &&
          isEraser == other.isEraser &&
          strokeWidth == other.strokeWidth &&
          penStyle == other.penStyle &&
          color == other.color &&
          points.length == other.points.length &&
          (points.isEmpty ||
              (points.first == other.points.first &&
                  points.last == other.points.last));

  @override
  int get hashCode => Object.hash(
        points.length,
        points.isEmpty ? null : points.first,
        isEraser,
        strokeWidth,
        penStyle,
        color,
      );

  @override
  String toString() =>
      'HandwritingStroke(points: ${points.length}, rawPoints: ${rawPoints?.length}, isEraser: $isEraser, width: $strokeWidth, style: $penStyle, color: $color)';
}

/// Active drawing tool for the kinesthetic slate.
enum CanvasTool {
  pen,
  eraser,
}
