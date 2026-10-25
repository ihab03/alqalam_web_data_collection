import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/stroke_models.dart';

/// Result container holding offscreen rasterized tensor assets for a single line band.
class RasterizedLineResult {
  /// 0-indexed line band index.
  final int lineIndex;

  /// Encoded PNG image bytes of size [paddedWidth] × [targetHeight] (64px).
  final Uint8List pngBytes;

  /// Raw uncompressed RGBA pixel bytes (length = [paddedWidth] × [targetHeight] × 4).
  final Uint8List rgbaBytes;

  /// The raw (unpadded) scaled pixel width computed from the cropped bounding box.
  final int rawWidth;

  /// The final width in pixels, padded to the nearest multiple of 32.
  final int paddedWidth;

  /// The fixed target image height in pixels (strictly 64).
  final int targetHeight;

  /// The scaling factor applied from CSS pixels to target pixels (64.0 / 108.0).
  final double scale;

  /// Bounding box minimum x in unscaled CSS pixels.
  final double minX;

  /// Bounding box maximum x in unscaled CSS pixels.
  final double maxX;

  /// Horizontal crop start x in unscaled CSS pixels ([minX] - 16.0).
  final double cropMinX;

  /// Horizontal crop end x in unscaled CSS pixels ([maxX] + 16.0).
  final double cropMaxX;

  /// Top y coordinate of the line band in unscaled CSS pixels.
  final double bandTopY;

  /// Bottom y coordinate of the line band in unscaled CSS pixels ([bandTopY] + 108.0).
  final double bandBottomY;

  /// The strokes belonging to this line band.
  final List<HandwritingStroke> strokes;

  const RasterizedLineResult({
    required this.lineIndex,
    required this.pngBytes,
    required this.rgbaBytes,
    required this.rawWidth,
    required this.paddedWidth,
    this.targetHeight = 64,
    required this.scale,
    required this.minX,
    required this.maxX,
    required this.cropMinX,
    required this.cropMaxX,
    required this.bandTopY,
    required this.bandBottomY,
    required this.strokes,
  });
}

/// Offscreen rasterization and tensor generation service for handwriting strokes.
///
/// Implements Section 3.1 of the frontend specification for the CRNN ONNX model:
/// - Constant line band height = 108.0 CSS px.
/// - Target rendered height = 64.0 px.
/// - Uniform scale factor = 64.0 / 108.0 (~0.5925926).
/// - Horizontal crop: [min_x - 16, max_x + 16] with minimum raw width of 32px.
/// - Padded width: paddedW = nearest multiple of 32 (((rawW + 31) ~/ 32) * 32).
/// - Rendering style: White background (#FFFFFF), black ink (#000000),
///   constant stroke width 2.2 px at height 64, round caps and joins, antialiased.
/// - Exports encoded PNG bytes and raw RGBA bytes of exact dimensions paddedW × 64.
class CanvasRasterizer {
  /// Constant handwriting line band height in unscaled CSS pixels.
  static const double bandHeight = 108.0;

  /// Fixed target height in pixels for the CRNN model input tensor.
  static const double targetHeight = 64.0;

  /// Scale factor mapping band height (108.0 CSS px) to target height (64.0 px).
  static const double scale = targetHeight / bandHeight; // ~0.5925925925925926

  /// Horizontal crop padding added to both left and right edges (16 CSS px each).
  static const double horizontalPadding = 16.0;

  /// Minimum cropped width in pixels.
  static const int minWidthPx = 32;

  /// Multiple to which the image width must be padded for CRNN downsampling (32 px).
  static const int padMultiple = 32;

  /// Constant stroke thickness in pixels at target height 64.
  static const double strokeWidthAt64 = 2.2;

  const CanvasRasterizer();

  /// Calculates the horizontal bounding box for the given [strokes].
  ///
  /// Returns a record with (minX, maxX). If strokes or points are empty,
  /// returns (0.0, 0.0).
  ({double minX, double maxX}) calculateHorizontalBounds(
    List<HandwritingStroke> strokes,
  ) {
    double minX = double.infinity;
    double maxX = -double.infinity;

    for (final stroke in strokes) {
      for (final p in stroke.effectiveRawPoints) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
      }
    }

    if (minX.isInfinite || maxX.isInfinite) {
      return (minX: 0.0, maxX: 0.0);
    }

    return (minX: minX, maxX: maxX);
  }

  /// Calculates [rawW] and [paddedW] for the given horizontal bounds in CSS pixels.
  ///
  /// Horizontal crop: [min_x - 16, max_x + 16] with minimum width of 32px.
  /// Padded width: (((rawW + 31) ~/ 32) * 32).
  ({double cropMinX, double cropMaxX, int rawW, int paddedW}) calculateDimensions({
    required double minX,
    required double maxX,
  }) {
    final cropMinX = minX - horizontalPadding;
    final cropMaxX = maxX + horizontalPadding;
    final rawCssWidth = cropMaxX - cropMinX;

    // Convert CSS width to target pixels at height 64
    final scaledRawWidth = rawCssWidth * scale;

    // Apply minimum width of 32px
    final rawW = math.max(minWidthPx, scaledRawWidth.ceil());

    // Calculate padded width as nearest multiple of 32
    final paddedW = ((rawW + (padMultiple - 1)) ~/ padMultiple) * padMultiple;

    return (
      cropMinX: cropMinX,
      cropMaxX: cropMaxX,
      rawW: rawW,
      paddedW: paddedW,
    );
  }

  /// Rasterizes strokes for a single line band into offscreen [ui.Image] assets,
  /// exporting both PNG and raw RGBA bytes of dimensions [paddedW] × 64.
  Future<RasterizedLineResult> rasterizeLine({
    required List<HandwritingStroke> strokes,
    required double bandTopY,
    int lineIndex = 0,
  }) async {
    final bounds = calculateHorizontalBounds(strokes);
    final dims = calculateDimensions(
      minX: bounds.minX,
      maxX: bounds.maxX,
    );

    final paddedW = dims.paddedW;
    const targetH = targetHeight;
    final bandBottomY = bandTopY + bandHeight;

    // Offscreen rendering pipeline via ui.PictureRecorder and ui.Canvas
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, paddedW.toDouble(), targetH),
    );

    // 1. Pristine white background (#FFFFFF)
    final bgPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, paddedW.toDouble(), targetH),
      bgPaint,
    );

    // Clip to strictly paddedW × 64
    canvas.clipRect(Rect.fromLTWH(0, 0, paddedW.toDouble(), targetH));

    // 2. Offscreen Paint configurations
    // Black ink (#000000), constant stroke width 2.2 px at height 64,
    // round caps & joins, antialiasing enabled.
    final inkPaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidthAt64
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final dotPaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Eraser rendering: paints white with round caps/joins
    final eraserPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidthAt64 * 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final eraserDotPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Helper to project unscaled CSS points to target 64px image pixels
    Offset projectPoint(StrokePoint p) {
      final imgX = (p.dx - dims.cropMinX) * scale;
      final imgY = (p.dy - bandTopY) * scale;
      return Offset(imgX, imgY);
    }

    // 3. Draw strokes
    for (final stroke in strokes) {
      final points = stroke.effectiveRawPoints;
      if (points.isEmpty) continue;

      if (stroke.isEraser) {
        if (points.length == 1) {
          final center = projectPoint(points[0]);
          canvas.drawCircle(center, (strokeWidthAt64 * 3.5) / 2, eraserDotPaint);
        } else {
          final path = Path();
          final start = projectPoint(points[0]);
          path.moveTo(start.dx, start.dy);
          for (var i = 1; i < points.length; i++) {
            final pt = projectPoint(points[i]);
            path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path, eraserPaint);
        }
      } else {
        // Black ink stroke
        if (points.length == 1) {
          // Single dot / diacritical point (nuqta)
          final center = projectPoint(points[0]);
          canvas.drawCircle(center, strokeWidthAt64 / 2, dotPaint);
        } else {
          final path = Path();
          final start = projectPoint(points[0]);
          path.moveTo(start.dx, start.dy);
          for (var i = 1; i < points.length; i++) {
            final pt = projectPoint(points[i]);
            path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path, inkPaint);
        }
      }
    }

    // 4. Conclude recording and extract image byte buffers
    final picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(paddedW, targetH.toInt());

    final pngByteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final rgbaByteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    image.dispose();

    final pngBytes = pngByteData!.buffer.asUint8List();
    final rgbaBytes = rgbaByteData!.buffer.asUint8List();

    return RasterizedLineResult(
      lineIndex: lineIndex,
      pngBytes: pngBytes,
      rgbaBytes: rgbaBytes,
      rawWidth: dims.rawW,
      paddedWidth: dims.paddedW,
      targetHeight: targetH.toInt(),
      scale: scale,
      minX: bounds.minX,
      maxX: bounds.maxX,
      cropMinX: dims.cropMinX,
      cropMaxX: dims.cropMaxX,
      bandTopY: bandTopY,
      bandBottomY: bandBottomY,
      strokes: strokes,
    );
  }

  /// Encodes strokes within [bandTopY] directly to PNG image bytes.
  Future<Uint8List> rasterizeToPng({
    required List<HandwritingStroke> strokes,
    required double bandTopY,
    int lineIndex = 0,
  }) async {
    final result = await rasterizeLine(
      strokes: strokes,
      bandTopY: bandTopY,
      lineIndex: lineIndex,
    );
    return result.pngBytes;
  }

  /// Exports raw RGBA bytes of dimensions strictly [paddedW] × 64.
  Future<Uint8List> rasterizeToRgba({
    required List<HandwritingStroke> strokes,
    required double bandTopY,
    int lineIndex = 0,
  }) async {
    final result = await rasterizeLine(
      strokes: strokes,
      bandTopY: bandTopY,
      lineIndex: lineIndex,
    );
    return result.rgbaBytes;
  }
}
