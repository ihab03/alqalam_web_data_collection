# Mobile & Web Canvas Data Collection Specification (Flutter Handoff)

**Document Version:** 2.0 (Two-Tier Web & Crowd Deployment — Task 4.2k Upgrade)  
**Target Manifest:** `data/mobile_collection/collection_manifest.json` (Seed `42`)  
**Deployment Target:** Flutter Web on iPad / Android Tablet browsers (Safari & Chrome)  
**Scope:**  
- **Tier 1 (Core):** 4 Dedicated Writers (`w01`–`w04`), 130 prompts/writer = **520 items** (`tier: "core_130"`).
- **Tier 2 (Crowd):** 100 Micro-Batches (`c001`–`c100`), 15 prompts/batch = **1,500 items** (`tier: "crowd_15"`).
- **Total Dataset:** 104 sessions, **2,020 total recordings** across **1,621 unique Quran spans**.
- **Intentional Errors:** 260 items (60 Core + 200 Crowd), strictly `is_training_eligible: false`.

---

## 1. Architecture & Two-Tier Session Routing

The Flutter Web application functions as a zero-logic, responsive prompt player and stroke recorder.

```
                                  USER ARRIVES VIA URL
                                           │
                    ┌──────────────────────┴──────────────────────┐
                    │                                             │
         ?writer=w01..w04 (URL Param)                    Default Link (No Param)
                    │                                             │
             TIER 1: CORE (130 Prompts)                    TIER 2: CROWD (15 Prompts)
                    │                                             │
           Selects w01..w04                             Auto-claims next unclaimed
           Auto-resumes (1..130)                        batch c001..c100 via localStorage
                    │                                             │
     Packs: A:25, B:80, C:10, D:15                Packs: A:3, B:9, C:1, D:2
                    │                                             │
                    └──────────────────────┬──────────────────────┘
                                           │
                                  PROMPT PLAYER UI
               - Displays RTL Arabic Prompt Text
               - If ui_notice_ar != null: Prominent Amber Notice Banner ⚠️
               - Locked ~6:1 Canvas Aspect Ratio (108 logical px height)
               - Blocks desktop mouse input (requires Stylus or Touch)
                                           │
                                  [ Submit & Next ]
                                           │
                               IMMEDIATE HTTP UPLOAD
               Uploads line_0.png (+ line_1.png) + record.json immediately
               (Does NOT wait for the entire 15 or 130 batch to finish)
                                           │
                         If Crowd Batch (15/15) Finished:
                         "Contribute 15 More" Button -> claims c00X+1
```

### 1.1 Tier 1: Core Writers (`tier: "core_130"`, `w01`–`w04`)
- **URL Syntax:** `https://<domain>/#/?writer=w01` (supports `w01`, `w02`, `w03`, `w04`).
- **Session Length:** 130 prompts per writer.
- **Pack Distribution:**
  - **Pack A (`shared_core`, 25 items, seq 1–25):** First 3 items (`shared_001`..`shared_003`) are universal ultra-dense calibration anchors; items 4–25 complete 100% vocab coverage, 5 mutashabihat spans, and 5 cross-ayah spans.
  - **Pack B (`disjoint_coverage`, 80 items, seq 26–105):** 60% mid-ayah, 25% short/full ayah, 15% cross-ayah, 0% overlap across writers.
  - **Pack C (`multiline_cross_ayah`, 10 items, seq 106–115):** 2–3 stacked lines (6–12 words total) crossing ayah boundary.
  - **Pack D (`intentional_error_eval`, 15 items, seq 116–130):** 6 categories of real error frames (`is_training_eligible: false`).
- **Auto-Resume:** Checks server or local storage for completed `prompt_id` records and resumes at the lowest incomplete `seq_index`.

### 1.2 Tier 2: Community Crowd (`tier: "crowd_15"`, `c001`–`c100`)
- **URL Syntax:** Default link with no `writer` query param (e.g. `https://<domain>/`).
- **Batch Size:** 15 prompts (takes 4–6 minutes per contributor).
- **Auto-Claim Mechanism:**
  1. App reads `localStorage.getItem('hafs_current_crowd_batch')`.
  2. If none, calls backend `/api/claim_batch` (or iterates `c001`..`c100` against local completion records) to claim the next available batch ID.
  3. Saves the claimed batch ID in `localStorage`.
- **Pack Distribution (15 prompts):**
  - **Pack A (`shared_core`, 3 items, seq 1–3):** The exact universal anchor spans `shared_001`..`shared_003` from Core Pack A.
  - **Pack B (`disjoint_coverage`, 9 items, seq 4–12):** 3–5 words per single line (balanced across crowd: 60% mid, 25% full/edge, 15% cross).
  - **Pack C (`multiline_cross_ayah`, 1 item, seq 13):** 2 stacked canvas lines (6–8 words total, 3–4 words/line) crossing an ayah boundary.
  - **Pack D (`intentional_error_eval`, 2 items, seq 14–15):** 1 confusable/particle error + 1 word omission/swap or Mutashabihat trap (`is_training_eligible: false`).
- **"Contribute 15 More" Flow:**
  When prompt 15/15 is submitted, show a celebration screen:
  > *"جزاكم الله خيراً! تم تسجيل الحزمة بنجاح."*  
  > Provide a prominent button **"المساهمة في 15 آية إضافية" (Contribute 15 More)**.  
  > Clicking it claims the next batch ID (`c002`, `c003`, etc.) and starts at `seq_index: 1`.

---

## 2. Intentional Error Banner (`ui_notice_ar != null`)

### 2.1 The Problem
When Hafiz/devout Muslim scribes see an intentional typo in a Quranic verse (Pack D), their subconscious memory instinct causes them to **auto-correct the word** while writing. This invalidates the negative/confusable testing frame.

### 2.2 The Solution
Every item in the manifest includes `ui_notice_ar: string | null`.
On all Pack D items (60 Core + 200 Crowd = **260 items**), `ui_notice_ar` is populated with:
```
"🎯 اختبار دقة للذكاء الاصطناعي: هذه الآية معدّلة عمداً لاختبار المصحح الذكي — يرجى كتابة النص المعروض أمامك حرفياً كما هو حتى لو اختلف عن حفظك."
```

### 2.3 Banner UI Rules
- When `ui_notice_ar != null`, render a **prominent amber/yellow warning card** directly above the prompt text.
- **Background:** Amber 50 (`#FFFBEB`).
- **Border:** Amber 300 (`#FCD34D`), `1.5 px` border width.
- **Text Color:** Amber 900 (`#78350F`), bold font, font size `14–16 sp`, RTL alignment.
- **Icon:** `Icons.warning_amber_rounded` or `🎯` emoji.
- For Pack A/B/C (`ui_notice_ar == null`), do not render the banner.

```dart
Widget buildNoticeBanner(String? noticeText) {
  if (noticeText == null) return const SizedBox.shrink();
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    padding: const EdgeInsets.all(12.0),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: Row(
      textDirection: TextDirection.rtl,
      children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            noticeText,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Color(0xFF78350F),
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
```

---

## 3. Web Canvas Guardrails & Touch Tracking

### 3.1 Aspect Ratio Locking in Viewport
- **Canonical Band Geometry:** Aspect ratio $\approx 6:1$ (`width : height`).
- In Flutter Web, tablet screens vary widely. The canvas box must be constrained:
  - `maxWidth`: `840 logical px`.
  - `height`: Fixed `108 logical px` (matching the CRNN model's canonical training band).
  - Use `AspectRatio(aspectRatio: 7.7, ...)` or a centered container with:
    ```dart
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 840, minWidth: 480, maxHeight: 108, minHeight: 108),
      child: ...,
    )
    ```
- Wrap stacked boxes in a scrollable `SingleChildScrollView` to prevent keyboard or UI clipping.

### 3.2 Pointer Kind Logging & Desktop Mouse Blocker
HTR models trained on tablet stylus/finger data fail on mouse input due to unnatural linear velocity, jerk, and lack of pressure.
- **Track Pointer Kind:** In Flutter `PointerEvent`, inspect `event.kind` (`PointerDeviceKind.stylus`, `PointerDeviceKind.touch`, `PointerDeviceKind.mouse`).
- **Desktop Mouse Blocker:** If `event.kind == PointerDeviceKind.mouse`, block drawing and display a friendly dialog:
  > *"⚠️ تنبيه: يرجى فتح الرابط على جهاز لوحي (iPad / Tablet) باستخدام القلم أو اللمس. تم تعطيل الرسم بالفأرة (Mouse) لضمان جودة البيانات التدريبية."*

```dart
Listener(
  onPointerDown: (PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      showMouseWarningDialog(context);
      return;
    }
    final pointerKindStr = event.kind == PointerDeviceKind.stylus ? "stylus" : "touch";
    recorder.startStroke(event.localPosition.dx, event.localPosition.dy, event.pressure, pointerKindStr);
  },
  ...
)
```

### 3.3 Immediate Per-Prompt Upload
Do **not** buffer all 15 or 130 recordings in memory or wait until the end of the session.
On clicking **Submit & Next**:
1. Validate that all active canvas lines are non-empty ($\ge 1$ stroke with $\ge 2$ points).
2. Render `line_0.png` (and `line_1.png` if multiline) at native resolution via `PictureRecorder`.
3. Build the `record.json` payload.
4. Issue an asynchronous `POST /api/upload_recording` multipart request with `line_0.png`, `line_1.png`, and `record.json`.
5. Cache in browser `IndexedDB` or local storage as fallback if offline.
6. Instantly advance the UI to `seq_index + 1`.

---

## 4. Output Bundle Schema & Concrete Example

For every prompt submission, generate:
- `line_0.png` (and `line_1.png` if `num_canvas_lines == 2`).
- `record.json`.

### 4.1 Schema Fields
Every item echoes the manifest plus runtime telemetry:

```json
{
  "seq_index": 14,
  "prompt_id": "c001_014_error_001",
  "writer_id": "c001",
  "tier": "crowd_15",
  "pack_type": "intentional_error_eval",
  "is_training_eligible": false,
  "num_canvas_lines": 1,
  "surah": 10,
  "ayah_start": 60,
  "ayah_end": 60,
  "g_start": 27497,
  "g_end": 27501,
  "display_text_uthmani": "ٱلَّذِى يَفْتَرُونَ عَلَى ٱللَّهِ ٱلْكَذِبَ",
  "written_imlai": "الذي يفترون على الله الكذب",
  "canonical_imlai": "الذين يفترون على الله الكذب",
  "line_prompts": [
    {
      "line_index": 0,
      "g_start": 27497,
      "g_end": 27501,
      "display_text_uthmani": "ٱلَّذِى يَفْتَرُونَ عَلَى ٱللَّهِ ٱلْكَذِبَ",
      "written_imlai": "الذي يفترون على الله الكذب"
    }
  ],
  "error_meta": {
    "category": "confusable",
    "target_word_index": 0,
    "canonical_token": "الذين",
    "mutated_token": "الذي",
    "description": "Confusable word swap: 'الذين' -> 'الذي'"
  },
  "ui_notice_ar": "🎯 اختبار دقة للذكاء الاصطناعي: هذه الآية معدّلة عمداً لاختبار المصحح الذكي — يرجى كتابة النص المعروض أمامك حرفياً كما هو حتى لو اختلف عن حفظك.",
  "capture_meta": {
    "recorded_at_utc": "2026-10-22T08:15:30.123Z",
    "user_agent": "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15",
    "device_pixel_ratio": 2.0,
    "input_mode": "stylus",
    "primary_pointer_kind": "stylus"
  },
  "lines": [
    {
      "line_index": 0,
      "canvas_width_logical": 756.0,
      "canvas_height_logical": 108.0,
      "image_width_px": 1512,
      "image_height_px": 216,
      "png_filename": "line_0.png",
      "strokes": [
        [
          {"x": 680.5, "y": 42.1, "t_ms": 1792656930123, "p": 0.68, "kind": "stylus"},
          {"x": 678.2, "y": 44.0, "t_ms": 1792656930139, "p": 0.74, "kind": "stylus"}
        ]
      ]
    }
  ]
}
```

---

## 5. Flutter Web Implementation Reference

### 5.1 Query Parameter Routing & Crowd Batch Claiming
```dart
import 'dart:html' as html;

class SessionManager {
  static String resolveWriterId(Map<String, List<dynamic>> manifestWriters) {
    // 1. Check URL query parameters (e.g. ?writer=w02)
    final uri = Uri.base;
    final writerParam = uri.queryParameters['writer'];
    if (writerParam != null && writerParam.isNotEmpty) {
      if (manifestWriters.containsKey(writerParam)) {
        return writerParam; // Tier 1 Core writer
      }
    }

    // 2. Check localStorage for existing Crowd batch
    final storedBatch = html.window.localStorage['hafs_current_crowd_batch'];
    if (storedBatch != null && manifestWriters.containsKey(storedBatch)) {
      return storedBatch;
    }

    // 3. Auto-claim first available crowd batch (c001..c100)
    for (int i = 1; i <= 100; i++) {
      final batchId = 'c${i.toString().padLeft(3, '0')}';
      final isDone = html.window.localStorage['hafs_batch_done_$batchId'] == 'true';
      if (!isDone && manifestWriters.containsKey(batchId)) {
        html.window.localStorage['hafs_current_crowd_batch'] = batchId;
        return batchId;
      }
    }

    return 'c001'; // Fallback
  }

  static void markBatchComplete(String batchId) {
    html.window.localStorage['hafs_batch_done_$batchId'] = 'true';
    html.window.localStorage.remove('hafs_current_crowd_batch');
  }
}
```

### 5.2 Stroke Recorder & Pointer Listener
```dart
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class StrokePoint {
  final double x;
  final double y;
  final int tMs;
  final double p;
  final String kind;

  StrokePoint({required this.x, required this.y, required this.tMs, required this.p, required this.kind});

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 't_ms': tMs, 'p': p, 'kind': kind};
}

class CanvasLineRecorder {
  final int lineIndex;
  final List<List<StrokePoint>> strokes = [];
  List<StrokePoint>? _current;

  CanvasLineRecorder({required this.lineIndex});

  void startStroke(double x, double y, double pressure, String kind) {
    _current = [StrokePoint(
      x: x, y: y,
      tMs: DateTime.now().millisecondsSinceEpoch,
      p: pressure > 0 ? pressure : 1.0,
      kind: kind,
    )];
    strokes.add(_current!);
  }

  void appendPoint(double x, double y, double pressure, String kind) {
    _current?.add(StrokePoint(
      x: x, y: y,
      tMs: DateTime.now().millisecondsSinceEpoch,
      p: pressure > 0 ? pressure : 1.0,
      kind: kind,
    ));
  }

  void endStroke() => _current = null;
  void clear() { strokes.clear(); _current = null; }
  bool get isEmpty => strokes.every((s) => s.length < 2);
}
```

### 5.3 PNG Rasterizer & Immediate Upload Routine
```dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

Future<void> submitAndUploadPrompt({
  required Map<String, dynamic> promptItem,
  required List<CanvasLineRecorder> lineRecorders,
  required double logicalWidth,
  required double logicalHeight,
  required double dpr,
}) async {
  final int pixelW = (logicalWidth * dpr).round();
  final int pixelH = (logicalHeight * dpr).round();
  final request = http.MultipartRequest('POST', Uri.parse('/api/recordings/upload'));

  final List<Map<String, dynamic>> linesData = [];

  for (int i = 0; i < lineRecorders.length; i++) {
    final rec = lineRecorders[i];
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr, dpr);

    // Render pure white background and 3.0px pure black ink
    canvas.drawRect(Rect.fromLTWH(0, 0, logicalWidth, logicalHeight), Paint()..color = Colors.white);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in rec.strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].x, stroke[0].y);
      for (int k = 1; k < stroke.length; k++) path.lineTo(stroke[k].x, stroke[k].y);
      canvas.drawPath(path, paint);
    }

    final img = await recorder.endRecording().toImage(pixelW, pixelH);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final pngFilename = 'line_$i.png';
    request.files.add(http.MultipartFile.fromBytes('files', pngBytes, filename: pngFilename));

    linesData.add({
      'line_index': i,
      'canvas_width_logical': logicalWidth,
      'canvas_height_logical': logicalHeight,
      'image_width_px': pixelW,
      'image_height_px': pixelH,
      'png_filename': pngFilename,
      'strokes': rec.strokes.map((s) => s.map((pt) => pt.toJson()).toList()).toList(),
    });
  }

  // Build record.json
  final recordJson = Map<String, dynamic>.from(promptItem);
  recordJson['capture_meta'] = {
    'recorded_at_utc': DateTime.now().toUtc().toIso8601String(),
    'device_pixel_ratio': dpr,
    'user_agent': html.window.navigator.userAgent,
  };
  recordJson['lines'] = linesData;

  request.files.add(http.MultipartFile.fromString(
    'record',
    jsonEncode(recordJson),
    filename: 'record.json',
  ));

  // Immediate upload to backend
  final response = await request.send();
  if (response.statusCode != 200 && response.statusCode != 201) {
    // Cache locally in IndexedDB/localStorage for background retry
    html.window.localStorage['hafs_pending_${promptItem['prompt_id']}'] = jsonEncode(recordJson);
  }
}
```

---

## 6. Frontend Verification Checklist

| Requirement | Implementation Verification |
|:---|:---|
| **URL Routing** | `?writer=w01` loads 130 Core prompts; default link auto-claims `c001`..`c100` (15 prompts). |
| **Notice Banner** | Renders prominent yellow/amber banner on all 260 Pack D items (`ui_notice_ar != null`). |
| **Mouse Blocking** | Checks `event.kind == PointerDeviceKind.mouse` and blocks desktop mouse drawing. |
| **Aspect Ratio** | Fixed height `108 logical px` ($~6:1$ ratio); canvas never stretches or overflows. |
| **Immediate Upload** | Transmits PNG(s) + `record.json` immediately on `Submit & Next`; does not buffer session. |
| **Continuous Crowd** | Shows "Contribute 15 More" button at `15/15` to smoothly claim next crowd batch. |
| **Clean PNG Export** | White background (`#FFFFFF`), pure black ink (`#000000`), zero guide lines or watermarks. |
