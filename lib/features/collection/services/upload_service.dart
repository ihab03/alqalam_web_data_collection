import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/storage/storage_service.dart';
import '../../canvas/domain/canvas_line_recorder.dart';
import '../data/session_manager.dart';
import '../domain/prompt_models.dart';

class UploadResult {
  final bool success;
  final int statusCode;
  final String? responseBody;
  final bool cachedLocally;
  final String? errorMessage;
  final String? storagePath;

  const UploadResult({
    required this.success,
    this.statusCode = 0,
    this.responseBody,
    this.cachedLocally = false,
    this.errorMessage,
    this.storagePath,
  });
}

/// Service that rasterizes canonical line PNGs and uploads bundles directly
/// into Supabase Storage bucket 'alqalam-recordings'.
class UploadService {
  final String targetBucket;
  final StorageService storage;
  final SupabaseClient? customClient;
  final String? contributorKey;
  final String? contributorName;
  final String? contributorUid;

  UploadService({
    this.targetBucket = 'alqalam-recordings',
    StorageService? storage,
    this.customClient,
    this.contributorKey,
    this.contributorName,
    this.contributorUid,
  }) : storage = storage ?? StorageService.instance;

  SupabaseClient? get _client {
    if (customClient != null) return customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Rasterizes canonical line PNGs and uploads directly to Supabase Storage.
  ///
  /// Target path: recordings/${contributorKey}/${writerId}/${promptId}/
  /// - line_0.png (and line_1.png if multiline) with contentType: 'image/png'
  /// - record.json with contentType: 'application/json'
  /// - fileOptions: const FileOptions(upsert: true)
  Future<UploadResult> submitAndUploadPrompt({
    required PromptItem promptItem,
    required List<CanvasLineRecorder> lineRecorders,
    required double logicalWidth,
    required double logicalHeight,
    required double dpr,
    String? contributorKey,
    String? contributorName,
    String? contributorUid,
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

      // Pure white background (#FFFFFF)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, logicalWidth, logicalHeight),
        Paint()..color = const Color(0xFFFFFFFF),
      );

      // Pure black ink (#000000), 3.0 px stroke width, rounded caps & joins
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

    // 2. Build record.json schema with contributor provenance
    final sessionManager = SessionManager(storage: storage);
    final resolvedContributorKey = contributorKey ??
        this.contributorKey ??
        sessionManager.contributorDirectoryKey;
    final resolvedContributorName = contributorName ??
        this.contributorName ??
        sessionManager.contributorName;
    final resolvedContributorUid = contributorUid ??
        this.contributorUid ??
        sessionManager.contributorUid;

    final Map<String, dynamic> recordJson = Map<String, dynamic>.from(promptItem.rawJson);
    recordJson['capture_meta'] = {
      'recorded_at_utc': DateTime.now().toUtc().toIso8601String(),
      'user_agent': storage.getUserAgent(),
      'device_pixel_ratio': dpr,
      'input_mode': primaryPointerKind,
      'primary_pointer_kind': primaryPointerKind,
      'contributor_name': resolvedContributorName,
      'contributor_uid': resolvedContributorUid,
    };
    recordJson['lines'] = linesData;

    final recordJsonString = jsonEncode(recordJson);
    final writerId = promptItem.writerId;
    final promptId = promptItem.promptId;

    // Isolated per-user storage path:
    final folderPath = 'recordings/$resolvedContributorKey/$writerId/$promptId';

    // 3. Upload directly to Supabase Storage bucket 'alqalam-recordings'
    try {
      final client = _client;
      if (client == null) {
        throw Exception('Supabase client is not initialized');
      }

      final storageBucket = client.storage.from(targetBucket);

      // Upload binary line PNGs
      for (final img in lineImages) {
        final filePath = '$folderPath/${img.filename}';
        await storageBucket.uploadBinary(
          filePath,
          img.bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png',
          ),
        );
      }

      // Upload UTF-8 encoded record.json
      final recordBytes = Uint8List.fromList(utf8.encode(recordJsonString));
      final recordPath = '$folderPath/record.json';
      await storageBucket.uploadBinary(
        recordPath,
        recordBytes,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'application/json',
        ),
      );

      // Success: mark completed, clear any pending cache
      storage.setItem('hafs_completed_$promptId', 'true');
      storage.removeItem('hafs_pending_$promptId');

      return UploadResult(
        success: true,
        statusCode: 200,
        storagePath: folderPath,
        responseBody: 'Successfully uploaded $folderPath to $targetBucket',
      );
    } catch (e) {
      // Failure: cache local copy in localStorage so data is not lost
      _cacheOfflinePayload(promptId, recordJsonString);
      storage.setItem('hafs_completed_$promptId', 'true');

      return UploadResult(
        success: false,
        cachedLocally: true,
        storagePath: folderPath,
        errorMessage: e.toString(),
      );
    }
  }

  void _cacheOfflinePayload(String promptId, String recordJsonString) {
    storage.setItem('hafs_pending_$promptId', recordJsonString);
  }
}
