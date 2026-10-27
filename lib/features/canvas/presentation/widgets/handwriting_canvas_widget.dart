import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../domain/canvas_line_recorder.dart';

/// Interactive 108 logical px handwriting canvas band built strictly for
/// Section 3 & 5 of FLUTTER_COLLECTION_SPEC.md:
/// - Fixed height 108 logical px, max width 840 logical px.
/// - Blocks desktop mouse events (`PointerDeviceKind.mouse`).
/// - Captures stylus and touch events with sub-millisecond timestamps and pressure.
/// - Renders smooth 120fps Bézier curves with a subtle Hafs writing baseline.
class HandwritingCanvasBandWidget extends StatefulWidget {
  final CanvasLineRecorder recorder;
  final double maxWidth;
  final double height;
  final String? lineLabel;
  final String? linePromptText;
  final VoidCallback onMouseBlocked;
  final VoidCallback? onStrokeEnded;
  final bool Function()? onValidateCanWrite;

  const HandwritingCanvasBandWidget({
    super.key,
    required this.recorder,
    this.maxWidth = 840.0,
    this.height = 108.0,
    this.lineLabel,
    this.linePromptText,
    required this.onMouseBlocked,
    this.onStrokeEnded,
    this.onValidateCanWrite,
  });

  @override
  State<HandwritingCanvasBandWidget> createState() =>
      _HandwritingCanvasBandWidgetState();
}

class _HandwritingCanvasBandWidgetState
    extends State<HandwritingCanvasBandWidget> {
  // Primary pointer kind detected for telemetry
  String _detectedPointerKind = 'touch';

  String get detectedPointerKind => _detectedPointerKind;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth,
          minWidth: 320.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.lineLabel != null || widget.linePromptText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0, right: 4.0, left: 4.0),
                child: Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.lineLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          widget.lineLabel!,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    if (widget.linePromptText != null)
                      Flexible(
                        child: Text(
                          widget.linePromptText!,
                          textDirection: TextDirection.rtl,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Fixed 108px Canvas Band Container
            Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Focus(
                autofocus: true,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (PointerDownEvent event) {
                    FocusScope.of(context).requestFocus();

                    // Desktop Mouse Blocker (Section 3.2)
                    if (event.kind == PointerDeviceKind.mouse) {
                      widget.onMouseBlocked();
                      return;
                    }

                    // Validate if writing is permitted (e.g. compulsory contributor name check)
                    if (widget.onValidateCanWrite != null &&
                        !widget.onValidateCanWrite!()) {
                      return;
                    }

                    final kindStr = event.kind == PointerDeviceKind.stylus
                        ? 'stylus'
                        : 'touch';
                    _detectedPointerKind = kindStr;

                    final pos = event.localPosition;
                    // Clamp y to canvas height bounds
                    final clampedY = pos.dy.clamp(0.0, widget.height);
                    final clampedX = pos.dx;

                    widget.recorder.startStroke(
                      clampedX,
                      clampedY,
                      event.pressure > 0 ? event.pressure : 1.0,
                      kindStr,
                    );
                  },
                  onPointerMove: (PointerMoveEvent event) {
                    if (event.kind == PointerDeviceKind.mouse) return;
                    if (widget.recorder.currentStroke == null) return;

                    final kindStr = event.kind == PointerDeviceKind.stylus
                        ? 'stylus'
                        : 'touch';

                    final pos = event.localPosition;
                    final clampedY = pos.dy.clamp(0.0, widget.height);
                    final clampedX = pos.dx;

                    widget.recorder.appendPoint(
                      clampedX,
                      clampedY,
                      event.pressure > 0 ? event.pressure : 1.0,
                      kindStr,
                    );
                  },
                  onPointerUp: (PointerUpEvent event) {
                    if (event.kind == PointerDeviceKind.mouse) return;
                    if (widget.recorder.currentStroke == null) return;
                    widget.recorder.endStroke();
                    widget.onStrokeEnded?.call();
                  },
                  onPointerCancel: (PointerCancelEvent event) {
                    widget.recorder.endStroke();
                  },
                  child: ListenableBuilder(
                    listenable: widget.recorder,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: BandStrokesPainter(
                          strokes: widget.recorder.strokes,
                          currentStroke: widget.recorder.currentStroke,
                          baselineY: 75.0,
                        ),
                        size: Size(widget.maxWidth, widget.height),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hardware-accelerated canvas painter rendering strokes and canonical Quranic baseline.
class BandStrokesPainter extends CustomPainter {
  final List<List<StrokePoint>> strokes;
  final List<StrokePoint>? currentStroke;
  final double baselineY;

  BandStrokesPainter({
    required this.strokes,
    this.currentStroke,
    this.baselineY = 75.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle baseline guide at y = 75.0 px (canonical Hafs writing guide)
    _drawBaselineGuide(canvas, size);

    // 2. Setup ink paint: 3.0px pure black, rounded caps & joins
    final inkPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // 3. Draw committed strokes
    for (final stroke in strokes) {
      _drawSmoothStroke(canvas, stroke, inkPaint);
    }

    // 4. Draw currently active stroke (if not already included in strokes)
    if (currentStroke != null && !strokes.contains(currentStroke)) {
      _drawSmoothStroke(canvas, currentStroke!, inkPaint);
    }
  }

  void _drawBaselineGuide(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Dashed baseline
    const double dashWidth = 6.0;
    const double dashSpace = 4.0;
    double startX = 12.0;
    final double endX = size.width - 12.0;

    while (startX < endX) {
      canvas.drawLine(
        Offset(startX, baselineY),
        Offset(startX + dashWidth, baselineY),
        guidePaint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  void _drawSmoothStroke(Canvas canvas, List<StrokePoint> points, Paint paint) {
    if (points.isEmpty) return;

    if (points.length == 1) {
      // Single tap dot
      canvas.drawCircle(
        Offset(points[0].x, points[0].y),
        paint.strokeWidth / 2.0,
        paint..style = PaintingStyle.fill,
      );
      paint.style = PaintingStyle.stroke;
      return;
    }

    if (points.length == 2) {
      canvas.drawLine(
        Offset(points[0].x, points[0].y),
        Offset(points[1].x, points[1].y),
        paint,
      );
      return;
    }

    final path = ui.Path()..moveTo(points[0].x, points[0].y);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = Offset(points[i].x, points[i].y);
      final p1 = Offset(points[i + 1].x, points[i + 1].y);
      final mid = Offset((p0.dx + p1.dx) / 2.0, (p0.dy + p1.dy) / 2.0);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.x, points.last.y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BandStrokesPainter oldDelegate) {
    return true;
  }
}
