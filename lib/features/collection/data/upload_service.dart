import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/storage/storage_service.dart';
import '../../canvas/domain/canvas_line_recorder.dart';
import '../domain/prompt_models.dart';

class UploadResult {
  final bool success;
  final int statusCode;
  final String? responseBody;
  final bool cachedLocally;
  final String? errorMessage;

  const UploadResult({
    required this.success,
    this.statusCode = 0,
    this.responseBody,
    this.cachedLocally = false,
    this.errorMessage,
  });
}

/// Service that rasterizes canonical line PNGs and transmits multipart bundles to the backend.
class UploadService {
  String uploadEndpoint;
  final StorageService storage;

  UploadService({
    this.uploadEndpoint = '/api/recordings/upload',
    StorageService? storage,
  }) : storage = storage ?? StorageService.instance;

  /// Submits and uploads a single completed prompt bundle per Section 4 & 5.3.
  Future<UploadResult> submitAndUploadPrompt({
    required PromptItem promptItem,
    required List<CanvasLineRecorder> lineRecorders,
    required double logicalWidth,
    required double logicalHeight,
    required double dpr,
  }) async {
    final int pixelW = (logicalWidth * dpr).round();
    final int pixelH = (logicalHeight * dpr).round();

    // Determine primary pointer kind from recorded points
    String primaryPointerKind = 'touch';
    int stylusCount = 0;
    int touchCount = 0;
    for (final rec in lineRecorders) {
      for (final s in rec.strokes) {
        for (final pt in s) {
          if (pt.kind == 'stylus') {
            stylusCount++;
          } else {
            touchCount++;
          }
        }
      }
    }
    if (stylusCount >= touchCount && stylusCount > 0) {
      primaryPointerKind = 'stylus';
    }

    final List<Map<String, dynamic>> linesData = [];
    final List<({String filename, Uint8List bytes})> lineImages = [];

    // 1. Offscreen rasterize each line band via ui.PictureRecorder
    for (int i = 0; i < lineRecorders.length; i++) {
      final rec = lineRecorders[i];
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(dpr, dpr);

      // Render pure white background (#FFFFFF)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, logicalWidth, logicalHeight),
        Paint()..color = const Color(0xFFFFFFFF),
      );

      // Render 3.0px pure black ink (#000000) with rounded caps and joins
      final inkPaint = Paint()
        ..color = const Color(0xFF000000)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke;

      for (final stroke in rec.strokes) {
        if (stroke.length < 2) continue;
        final path = Path()..moveTo(stroke[0].x, stroke[0].y);
        for (int k = 1; k < stroke.length; k++) {
          path.lineTo(stroke[k].x, stroke[k].y);
        }
        canvas.drawPath(path, inkPaint);
      }

      final img = await recorder.endRecording().toImage(pixelW, pixelH);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final pngFilename = 'line_$i.png';
      lineImages.add((filename: pngFilename, bytes: pngBytes));

      linesData.add({
        'line_index': i,
        'canvas_width_logical': logicalWidth,
        'canvas_height_logical': logicalHeight,
        'image_width_px': pixelW,
        'image_height_px': pixelH,
        'png_filename': pngFilename,
        'strokes': rec.strokes
            .map((s) => s.map((pt) => pt.toJson()).toList())
            .toList(),
      });
    }

    // 2. Build record.json adhering strictly to Section 4 schema
    final Map<String, dynamic> recordJson = Map<String, dynamic>.from(promptItem.rawJson);
    recordJson['capture_meta'] = {
      'recorded_at_utc': DateTime.now().toUtc().toIso8601String(),
      'user_agent': storage.getUserAgent(),
      'device_pixel_ratio': dpr,
      'input_mode': primaryPointerKind,
      'primary_pointer_kind': primaryPointerKind,
    };
    recordJson['lines'] = linesData;

    final recordJsonString = jsonEncode(recordJson);

    // 3. Transmit via http.MultipartRequest
    try {
      final uri = Uri.parse(uploadEndpoint);
      final request = http.MultipartRequest('POST', uri);

      for (final img in lineImages) {
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          img.bytes,
          filename: img.filename,
        ));
      }

      request.files.add(http.MultipartFile.fromString(
        'record',
        recordJsonString,
        filename: 'record.json',
      ));

      request.fields['record_json'] = recordJsonString;
      request.fields['prompt_id'] = promptItem.promptId;
      request.fields['writer_id'] = promptItem.writerId;

      final streamedResponse = await request.send().timeout(const Duration(seconds: 12));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        // Mark prompt completed in storage
        storage.setItem('hafs_completed_${promptItem.promptId}', 'true');
        storage.removeItem('hafs_pending_${promptItem.promptId}');

        return UploadResult(
          success: true,
          statusCode: streamedResponse.statusCode,
          responseBody: responseBody,
        );
      } else {
        // Server returned non-200: cache locally for offline retry
        _cacheOfflinePayload(promptItem.promptId, recordJsonString);
        storage.setItem('hafs_completed_${promptItem.promptId}', 'true');

        return UploadResult(
          success: false,
          statusCode: streamedResponse.statusCode,
          cachedLocally: true,
          errorMessage: 'Server returned ${streamedResponse.statusCode}',
        );
      }
    } catch (e) {
      // Offline / network failure: cache locally
      _cacheOfflinePayload(promptItem.promptId, recordJsonString);
      storage.setItem('hafs_completed_${promptItem.promptId}', 'true');

      return UploadResult(
        success: false,
        cachedLocally: true,
        errorMessage: e.toString(),
      );
    }
  }

  void _cacheOfflinePayload(String promptId, String recordJsonString) {
    storage.setItem('hafs_pending_$promptId', recordJsonString);
  }
}
