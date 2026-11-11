import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alqalam_web_data_collection/core/storage/storage_service.dart';
import 'package:alqalam_web_data_collection/features/canvas/domain/canvas_line_recorder.dart';
import 'package:alqalam_web_data_collection/features/canvas/presentation/widgets/handwriting_canvas_widget.dart';
import 'package:alqalam_web_data_collection/features/collection/data/manifest_repository.dart';
import 'package:alqalam_web_data_collection/features/collection/data/session_manager.dart';
import 'package:alqalam_web_data_collection/features/collection/domain/prompt_models.dart';
import 'package:alqalam_web_data_collection/features/collection/presentation/collection_screen.dart';
import 'package:alqalam_web_data_collection/features/collection/presentation/widgets/celebration_view.dart';
import 'package:alqalam_web_data_collection/features/collection/presentation/widgets/notice_banner_widget.dart';
import 'package:alqalam_web_data_collection/features/collection/presentation/widgets/top_bar_widget.dart';
import 'package:alqalam_web_data_collection/features/collection/services/upload_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late SessionManager sessionManager;
  late ManifestData mockManifest;

  setUp(() {
    storage = StorageService.instance;
    storage.clearMemoryFallback();
    sessionManager = SessionManager(storage: storage);

    // Build mock manifest data for v2 (26 writer slots: e01..e03, s01..s20, t01..t03)
    final Map<String, List<PromptItem>> writers = {};

    // EVAL: e01..e03 (50 prompts each)
    for (final e in ['e01', 'e02', 'e03']) {
      writers[e] = List.generate(
        50,
        (i) {
          final seq = i + 1;
          String packType = 'disjoint_coverage';
          int numLines = 1;
          String? uiNotice;
          if (seq > 25 && seq <= 35) {
            packType = 'multiline_cross_ayah';
            numLines = seq <= 30 ? 2 : 3;
          } else if (seq > 35 && seq <= 40) {
            packType = 'long_multiline';
            numLines = 3;
          } else if (seq > 40) {
            packType = 'intentional_error_eval';
            uiNotice = '🎯 اختبار دقة للذكاء الاصطناعي';
          }
          final linePrompts = List.generate(
            numLines,
            (li) => LinePrompt(
              lineIndex: li,
              gStart: 1,
              gEnd: 4,
              displayTextUthmani: 'السطر ${li + 1}',
              writtenImlai: 'السطر ${li + 1}',
            ),
          );
          return PromptItem(
            seqIndex: seq,
            promptId: '${e}_${seq.toString().padLeft(3, '0')}_eval',
            writerId: e,
            tier: 'eval_50',
            assignment: 'EVAL',
            packType: packType,
            isTrainingEligible: seq <= 40,
            numCanvasLines: numLines,
            surah: 1,
            ayahStart: 1,
            ayahEnd: 1,
            gStart: 1,
            gEnd: 4,
            displayTextUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
            writtenImlai: 'بسم الله الرحمن الرحيم',
            canonicalImlai: 'بسم الله الرحمن الرحيم',
            linePrompts: linePrompts,
            uiNoticeAr: uiNotice,
            rawJson: {
              'seq_index': seq,
              'prompt_id': '${e}_${seq.toString().padLeft(3, '0')}_eval',
              'writer_id': e,
              'tier': 'eval_50',
              'assignment': 'EVAL',
              'pack_type': packType,
              'is_training_eligible': seq <= 40,
              'num_canvas_lines': numLines,
            },
          );
        },
      );
    }

    // EVAL_SHORT: s01..s20 (15 prompts each)
    for (int s = 1; s <= 20; s++) {
      final sid = 's${s.toString().padLeft(2, '0')}';
      writers[sid] = List.generate(
        15,
        (i) {
          final seq = i + 1;
          String packType = 'disjoint_coverage';
          int numLines = 1;
          String? uiNotice;
          if (seq == 7) {
            packType = 'multiline_cross_ayah';
            numLines = 2;
          } else if (seq == 8) {
            packType = 'multiline_cross_ayah';
            numLines = 3;
          } else if (seq == 9 || seq == 10) {
            packType = 'long_multiline';
            numLines = 3;
          } else if (seq >= 11) {
            packType = 'intentional_error_eval';
            uiNotice = '🎯 اختبار دقة للذكاء الاصطناعي';
          }
          final linePrompts = List.generate(
            numLines,
            (li) => LinePrompt(
              lineIndex: li,
              gStart: 1,
              gEnd: 4,
              displayTextUthmani: 'السطر ${li + 1}',
              writtenImlai: 'السطر ${li + 1}',
            ),
          );
          return PromptItem(
            seqIndex: seq,
            promptId: '${sid}_${seq.toString().padLeft(3, '0')}_short',
            writerId: sid,
            tier: 'eval_short_15',
            assignment: 'EVAL_SHORT',
            packType: packType,
            isTrainingEligible: seq <= 10,
            numCanvasLines: numLines,
            surah: 1,
            ayahStart: 1,
            ayahEnd: 1,
            gStart: 1,
            gEnd: 4,
            displayTextUthmani: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ',
            writtenImlai: 'الحمد لله رب العالمين',
            canonicalImlai: 'الحمد لله رب العالمين',
            linePrompts: linePrompts,
            uiNoticeAr: uiNotice,
            rawJson: {
              'seq_index': seq,
              'prompt_id': '${sid}_${seq.toString().padLeft(3, '0')}_short',
              'writer_id': sid,
              'tier': 'eval_short_15',
              'assignment': 'EVAL_SHORT',
              'pack_type': packType,
              'is_training_eligible': seq <= 10,
              'num_canvas_lines': numLines,
            },
          );
        },
      );
    }

    // TRAIN: t01..t03 (120 prompts each)
    for (final t in ['t01', 't02', 't03']) {
      writers[t] = List.generate(
        120,
        (i) {
          final seq = i + 1;
          final isMulti = seq > 100;
          final numLines = isMulti ? (seq <= 110 ? 2 : 3) : 1;
          final packType = isMulti ? 'multiline_cross_ayah' : 'disjoint_coverage';
          final linePrompts = List.generate(
            numLines,
            (li) => LinePrompt(
              lineIndex: li,
              gStart: 1,
              gEnd: 4,
              displayTextUthmani: 'السطر ${li + 1}',
              writtenImlai: 'السطر ${li + 1}',
            ),
          );
          return PromptItem(
            seqIndex: seq,
            promptId: '${t}_${seq.toString().padLeft(3, '0')}_train',
            writerId: t,
            tier: 'train_120',
            assignment: 'TRAIN',
            packType: packType,
            isTrainingEligible: true,
            numCanvasLines: numLines,
            surah: 2,
            ayahStart: seq,
            ayahEnd: seq,
            gStart: 1,
            gEnd: 4,
            displayTextUthmani: 'ذَٰلِكَ ٱلْكِتَٰبُ لَا رَيْبَ ۛ فِيهِ',
            writtenImlai: 'ذلك الكتاب لا ريب فيه',
            canonicalImlai: 'ذلك الكتاب لا ريب فيه',
            linePrompts: linePrompts,
            uiNoticeAr: null,
            rawJson: {
              'seq_index': seq,
              'prompt_id': '${t}_${seq.toString().padLeft(3, '0')}_train',
              'writer_id': t,
              'tier': 'train_120',
              'assignment': 'TRAIN',
              'pack_type': packType,
              'is_training_eligible': true,
              'num_canvas_lines': numLines,
            },
          );
        },
      );
    }

    mockManifest = ManifestData(metadata: {}, writers: writers);
    ManifestRepository.setMockData(mockManifest);
  });

  tearDown(() {
    ManifestRepository.clearCache();
  });

  group('SessionManager Strict Query Parameter Routing (v2 Named Slots)', () {
    test('?writer=e01 routes strictly to e01, eval_50 tier, EVAL assignment (50 prompts)', () {
      final uri = Uri.parse('https://example.com/#/?writer=e01');
      final result = sessionManager.resolveSession(uri, mockManifest);

      expect(result, isNotNull);
      expect(result!.writerId, 'e01');
      expect(result.tier, 'eval_50');
      expect(result.assignment, 'EVAL');
      expect(result.prompts.length, 50);
      expect(result.initialPromptIndex, 0);
    });

    test('?writer=s03 routes strictly to s03, eval_short_15 tier, EVAL_SHORT assignment (15 prompts)', () {
      final uri = Uri.parse('https://example.com/?writer=s03');
      final result = sessionManager.resolveSession(uri, mockManifest);

      expect(result, isNotNull);
      expect(result!.writerId, 's03');
      expect(result.tier, 'eval_short_15');
      expect(result.assignment, 'EVAL_SHORT');
      expect(result.prompts.length, 15);
      expect(result.initialPromptIndex, 0);
    });

    test('?writer=t02 routes strictly to t02, train_120 tier, TRAIN assignment (120 prompts)', () {
      final uri = Uri.parse('https://example.com/#/?writer=t02');
      final result = sessionManager.resolveSession(uri, mockManifest);

      expect(result, isNotNull);
      expect(result!.writerId, 't02');
      expect(result.tier, 'train_120');
      expect(result.assignment, 'TRAIN');
      expect(result.prompts.length, 120);
      expect(result.initialPromptIndex, 0);
    });

    test('Missing ?writer query parameter returns null (no auto-claim)', () {
      final uri = Uri.parse('https://example.com/#/');
      final result = sessionManager.resolveSession(uri, mockManifest);

      expect(result, isNull);
    });

    test('Unknown or invalid writer parameter returns null (no auto-assignment)', () {
      final invalidUris = [
        Uri.parse('https://example.com/#/?writer=w01'), // Old v1 slot
        Uri.parse('https://example.com/#/?writer=c001'), // Old crowd slot
        Uri.parse('https://example.com/#/?writer=xyz'),
        Uri.parse('https://example.com/?writer='),
      ];

      for (final u in invalidUris) {
        final result = sessionManager.resolveSession(u, mockManifest);
        expect(result, isNull, reason: 'URI $u should yield null session');
      }
    });

    test('Auto-resumes at the lowest incomplete seq_index', () {
      // Mark prompts 1, 2, 3 complete for e02
      sessionManager.markPromptCompleted('e02_001_eval');
      sessionManager.markPromptCompleted('e02_002_eval');
      sessionManager.markPromptCompleted('e02_003_eval');

      final uri = Uri.parse('https://example.com/#/?writer=e02');
      final result = sessionManager.resolveSession(uri, mockManifest);

      expect(result, isNotNull);
      expect(result!.writerId, 'e02');
      expect(result.initialPromptIndex, 3); // 0-indexed, so seq_index = 4
    });
  });

  group('SessionManager Contributor Key and Identity Tests', () {
    test('Generates and persists unique contributorUid in localStorage["hafs_contributor_uid"]', () {
      expect(storage.getItem('hafs_contributor_uid'), isNull);
      final uid = sessionManager.contributorUid;
      expect(uid, isNotEmpty);
      expect(storage.getItem('hafs_contributor_uid'), uid);

      // Subsequent access reuses the same persisted UID
      final uidAgain = sessionManager.contributorUid;
      expect(uidAgain, uid);
    });

    test('Reuses pre-existing contributorUid from localStorage', () {
      storage.setItem('hafs_contributor_uid', 'k8f2a1');
      expect(sessionManager.contributorUid, 'k8f2a1');
    });

    test('Defaults contributorName to "anonymous" when not set', () {
      expect(sessionManager.contributorName, 'anonymous');
    });

    test('Allows user to input and persist custom contributorName in localStorage["hafs_contributor_name"]', () {
      sessionManager.contributorName = 'Ahmed Ali';
      expect(sessionManager.contributorName, 'Ahmed Ali');
      expect(storage.getItem('hafs_contributor_name'), 'Ahmed Ali');

      // Empty or whitespace defaults back to anonymous
      sessionManager.contributorName = '   ';
      expect(sessionManager.contributorName, 'anonymous');
    });

    test('Sanitizes contributorName: lowercase, spaces to underscores, strips non-alphanumeric/Arabic characters', () {
      expect(SessionManager.sanitizeContributorName('Ahmed Ali'), 'ahmed_ali');
      expect(SessionManager.sanitizeContributorName('أحمد علي'), 'أحمد_علي');
      expect(SessionManager.sanitizeContributorName('Ahmed! @#\$ 2026-Test'), 'ahmed_2026test');
      expect(SessionManager.sanitizeContributorName('!@#\$%^&*()'), 'anonymous');
    });

    test('Formats contributorDirectoryKey as \${sanitizedName}_\${contributorUid}', () {
      storage.setItem('hafs_contributor_uid', 'k8f2a1');
      sessionManager.contributorName = 'Ahmed';
      expect(sessionManager.contributorDirectoryKey, 'ahmed_k8f2a1');

      storage.setItem('hafs_contributor_uid', '9x3m1q');
      sessionManager.contributorName = 'anonymous';
      expect(sessionManager.contributorDirectoryKey, 'anonymous_9x3m1q');

      storage.setItem('hafs_contributor_uid', '7z2b4x');
      sessionManager.contributorName = 'طارق';
      expect(sessionManager.contributorDirectoryKey, 'طارق_7z2b4x');
    });

    test('resolveSession includes contributorDirectoryKey, contributorName, and contributorUid in result', () {
      storage.setItem('hafs_contributor_uid', 'k8f2a1');
      sessionManager.contributorName = 'Ahmed';

      final uri = Uri.parse('https://example.com/#/?writer=e01');
      final result = sessionManager.resolveSession(uri, mockManifest);

      expect(result, isNotNull);
      expect(result!.contributorName, 'Ahmed');
      expect(result.contributorUid, 'k8f2a1');
      expect(result.contributorDirectoryKey, 'ahmed_k8f2a1');
    });

    test('hasCustomContributorName correctly reflects presence of non-anonymous contributor name', () {
      expect(sessionManager.hasCustomContributorName, isFalse);

      storage.setItem('hafs_contributor_name', 'anonymous');
      expect(sessionManager.hasCustomContributorName, isFalse);

      storage.setItem('hafs_contributor_name', 'Anonymous');
      expect(sessionManager.hasCustomContributorName, isFalse);

      storage.setItem('hafs_contributor_name', '   ');
      expect(sessionManager.hasCustomContributorName, isFalse);

      sessionManager.contributorName = 'Zaid Ali';
      expect(sessionManager.hasCustomContributorName, isTrue);

      sessionManager.contributorName = 'زيد علي';
      expect(sessionManager.hasCustomContributorName, isTrue);
    });
  });

  group('UploadService Multi-Band and v2 record.json Echo Tests', () {
    late UploadService uploadService;

    setUp(() {
      uploadService = UploadService(storage: storage);
    });

    test('Single-band prompt (num_canvas_lines = 1) generates line_0.png and echoes v2 manifest fields', () async {
      storage.setItem('hafs_contributor_uid', 'k8f2a1');
      sessionManager.contributorName = 'Ahmed';
      final contributorKey = sessionManager.contributorDirectoryKey;

      final promptItem = mockManifest.writers['e01']![0]; // seq 1: disjoint_coverage, 1 band
      expect(promptItem.numCanvasLines, 1);
      expect(promptItem.assignment, 'EVAL');
      expect(promptItem.tier, 'eval_50');

      final recorder = CanvasLineRecorder(lineIndex: 0);
      recorder.startStroke(10.0, 10.0, 1.0, 'stylus');
      recorder.appendPoint(30.0, 30.0, 1.0, 'stylus');
      recorder.endStroke();

      final result = await uploadService.submitAndUploadPrompt(
        promptItem: promptItem,
        lineRecorders: [recorder],
        logicalWidth: 800.0,
        logicalHeight: 108.0,
        dpr: 1.0,
        contributorKey: contributorKey,
        contributorName: 'Ahmed',
        contributorUid: 'k8f2a1',
      );

      final expectedPath = 'recordings/ahmed_k8f2a1/e01/${promptItem.promptId}';
      expect(result.storagePath, expectedPath);

      final cachedJsonStr = storage.getItem('hafs_pending_${promptItem.promptId}');
      expect(cachedJsonStr, isNotNull);

      final cachedJson = jsonDecode(cachedJsonStr!) as Map<String, dynamic>;

      // v2 manifest echo check
      expect(cachedJson['assignment'], 'EVAL');
      expect(cachedJson['tier'], 'eval_50');
      expect(cachedJson['pack_type'], 'disjoint_coverage');

      // capture_meta check
      final meta = cachedJson['capture_meta'] as Map<String, dynamic>;
      expect(meta['contributor_name'], 'Ahmed');
      expect(meta['contributor_uid'], 'k8f2a1');
      expect(meta['primary_pointer_kind'], 'stylus');

      // lines rasterization check: exactly 1 line
      final lines = cachedJson['lines'] as List<dynamic>;
      expect(lines.length, 1);
      expect(lines[0]['png_filename'], 'line_0.png');
      expect(lines[0]['canvas_height_logical'], 108.0);
    });

    test('3-Band long_multiline prompt generates line_0.png, line_1.png, line_2.png', () async {
      storage.setItem('hafs_contributor_uid', 'user123');
      storage.setItem('hafs_contributor_name', 'tester');

      // e01 item 36 is long_multiline (3 lines)
      final promptItem = mockManifest.writers['e01']![35];
      expect(promptItem.numCanvasLines, 3);
      expect(promptItem.packType, 'long_multiline');

      final rec0 = CanvasLineRecorder(lineIndex: 0);
      rec0.startStroke(10.0, 10.0, 1.0, 'touch');
      rec0.appendPoint(20.0, 20.0, 1.0, 'touch');
      rec0.endStroke();

      final rec1 = CanvasLineRecorder(lineIndex: 1);
      rec1.startStroke(30.0, 30.0, 1.0, 'touch');
      rec1.appendPoint(40.0, 40.0, 1.0, 'touch');
      rec1.endStroke();

      final rec2 = CanvasLineRecorder(lineIndex: 2);
      rec2.startStroke(50.0, 50.0, 1.0, 'touch');
      rec2.appendPoint(60.0, 60.0, 1.0, 'touch');
      rec2.endStroke();

      final result = await uploadService.submitAndUploadPrompt(
        promptItem: promptItem,
        lineRecorders: [rec0, rec1, rec2],
        logicalWidth: 840.0,
        logicalHeight: 108.0,
        dpr: 1.0,
      );

      expect(result.storagePath, 'recordings/tester_user123/e01/${promptItem.promptId}');

      final cachedJsonStr = storage.getItem('hafs_pending_${promptItem.promptId}');
      final cachedJson = jsonDecode(cachedJsonStr!) as Map<String, dynamic>;

      expect(cachedJson['assignment'], 'EVAL');
      expect(cachedJson['tier'], 'eval_50');
      expect(cachedJson['pack_type'], 'long_multiline');

      final lines = cachedJson['lines'] as List<dynamic>;
      expect(lines.length, 3);
      expect(lines[0]['png_filename'], 'line_0.png');
      expect(lines[1]['png_filename'], 'line_1.png');
      expect(lines[2]['png_filename'], 'line_2.png');
      expect(lines[0]['canvas_height_logical'], 108.0);
      expect(lines[1]['canvas_height_logical'], 108.0);
      expect(lines[2]['canvas_height_logical'], 108.0);
    });
  });

  group('CanvasLineRecorder Tests', () {
    test('Records stroke points with sub-millisecond timestamps, pressure, and kind', () {
      final recorder = CanvasLineRecorder(lineIndex: 0);
      expect(recorder.isEmpty, isTrue);

      recorder.startStroke(100.0, 50.0, 0.85, 'stylus');
      expect(recorder.currentStroke, isNotNull);
      expect(recorder.currentStroke!.first.p, 0.85);
      expect(recorder.currentStroke!.first.kind, 'stylus');

      recorder.appendPoint(105.0, 52.0, 0.90, 'stylus');
      recorder.endStroke();

      expect(recorder.strokes.length, 1);
      expect(recorder.strokes[0].length, 2);
      expect(recorder.hasValidContent, isTrue);
      expect(recorder.isEmpty, isFalse);
    });

    test('Undo and redo functionality', () {
      final recorder = CanvasLineRecorder(lineIndex: 0);
      recorder.startStroke(10.0, 10.0, 1.0, 'touch');
      recorder.appendPoint(20.0, 20.0, 1.0, 'touch');
      recorder.endStroke();

      expect(recorder.strokes.length, 1);
      expect(recorder.canUndo, isTrue);

      recorder.undo();
      expect(recorder.strokes.length, 0);
      expect(recorder.canRedo, isTrue);

      recorder.redo();
      expect(recorder.strokes.length, 1);
    });

    test('Clear removes all strokes and resets history', () {
      final recorder = CanvasLineRecorder(lineIndex: 0);
      recorder.startStroke(10.0, 10.0, 1.0, 'touch');
      recorder.appendPoint(20.0, 20.0, 1.0, 'touch');
      recorder.endStroke();

      recorder.clear();
      expect(recorder.strokes.isEmpty, isTrue);
      expect(recorder.canUndo, isFalse);
      expect(recorder.canRedo, isFalse);
    });
  });

  group('UI Components Widget Tests', () {
    testWidgets('IntentionalErrorBanner renders prominently when notice text present', (tester) async {
      const notice = '🎯 اختبار دقة للذكاء الاصطناعي: هذه الآية معدّلة عمداً';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntentionalErrorBanner(noticeText: notice),
          ),
        ),
      );

      expect(find.text(notice), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('IntentionalErrorBanner renders nothing when notice text is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntentionalErrorBanner(noticeText: null),
          ),
        ),
      );

      expect(find.byType(IntentionalErrorBanner), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('CelebrationView displays congratulations without Contribute 15 More button', (tester) async {
      bool reviewTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelebrationView(
              writerId: 'e01',
              tier: 'eval_50',
              assignment: 'EVAL',
              totalSubmitted: 50,
              onReviewPrompts: () {
                reviewTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('جزاكم الله خيراً!'), findsOneWidget);
      expect(find.text('تم إكمال جلسة التقييم (EVAL) بنجاح'), findsOneWidget);
      expect(find.text('مراجعة الآيات السابقة'), findsOneWidget);

      // Verify "Contribute 15 More" does NOT exist
      expect(find.text('المساهمة في 15 آية إضافية'), findsNothing);

      await tester.ensureVisible(find.text('مراجعة الآيات السابقة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مراجعة الآيات السابقة'));
      expect(reviewTapped, isTrue);
    });

    testWidgets('CollectionTopBar renders badges and progress correctly with writer slot and assignment', (tester) async {
      bool editTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(80.0),
              child: CollectionTopBar(
                writerId: 'e01',
                tier: 'eval_50',
                assignment: 'EVAL',
                currentIndex: 35,
                totalCount: 50,
                currentPrompt: mockManifest.writers['e01']![35], // long_multiline
                contributorName: 'Ahmed',
                onEditContributorName: () {
                  editTapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('الكاتب e01'), findsOneWidget);
      expect(find.text('تقييم'), findsOneWidget);
      expect(find.text('36 / 50'), findsOneWidget);
      expect(find.text('هـ: أسطر طويلة'), findsOneWidget);
      expect(find.text('Ahmed'), findsOneWidget);

      await tester.tap(find.text('Ahmed'));
      expect(editTapped, isTrue);
    });

    testWidgets('HandwritingCanvasBandWidget blocks mouse events and triggers callback', (tester) async {
      bool mouseBlocked = false;
      final recorder = CanvasLineRecorder(lineIndex: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HandwritingCanvasBandWidget(
              recorder: recorder,
              onMouseBlocked: () {
                mouseBlocked = true;
              },
            ),
          ),
        ),
      );

      // Simulate mouse pointer down
      final center = tester.getCenter(find.byType(CustomPaint).last);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: center);
      await gesture.down(center);
      await tester.pump();
      await gesture.up();

      expect(mouseBlocked, isTrue);
      // Recorder must remain empty because mouse was blocked
      expect(recorder.isEmpty, isTrue);
    });

    testWidgets('HandwritingCanvasBandWidget checks onValidateCanWrite before starting stroke', (tester) async {
      bool canWrite = false;
      int validateCallCount = 0;
      final recorder = CanvasLineRecorder(lineIndex: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HandwritingCanvasBandWidget(
              recorder: recorder,
              onMouseBlocked: () {},
              onValidateCanWrite: () {
                validateCallCount++;
                return canWrite;
              },
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(CustomPaint).last);

      // 1. Touch when canWrite is false: should block stroke
      final touch1 = await tester.createGesture(kind: PointerDeviceKind.touch);
      await touch1.addPointer(location: center);
      await touch1.down(center);
      await touch1.moveTo(Offset(center.dx + 20, center.dy + 20));
      await tester.pump();
      await touch1.up();

      expect(validateCallCount, 1);
      expect(recorder.isEmpty, isTrue);

      // 2. Touch when canWrite is true: should record stroke
      canWrite = true;
      final touch2 = await tester.createGesture(kind: PointerDeviceKind.touch);
      await touch2.addPointer(location: center);
      await touch2.down(center);
      await touch2.moveTo(Offset(center.dx + 20, center.dy + 20));
      await tester.pump();
      await touch2.up();

      expect(validateCallCount, 2);
      expect(recorder.isEmpty, isFalse);
    });

    testWidgets('CollectionTopBar renders "إدخال الاسم" when contributorName is anonymous', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(80.0),
              child: CollectionTopBar(
                writerId: 's01',
                tier: 'eval_short_15',
                assignment: 'EVAL_SHORT',
                currentIndex: 0,
                totalCount: 15,
                contributorName: 'anonymous',
              ),
            ),
          ),
        ),
      );

      expect(find.text('إدخال الاسم'), findsOneWidget);
    });
  });

  group('CollectionScreen V2 Integration Tests', () {
    testWidgets('Shows "رابط غير صالح أو مفقود" error screen when writer param is missing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionScreen(
            initialUri: Uri.parse('https://example.com/#/'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('رابط غير صالح أو مفقود'), findsOneWidget);
      expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
      expect(find.textContaining('e01 – e03'), findsOneWidget);
    });

    testWidgets('Shows "رابط غير صالح أو مفقود" error screen when writer param is an old v1 or unknown slot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionScreen(
            initialUri: Uri.parse('https://example.com/#/?writer=w01'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('رابط غير صالح أو مفقود'), findsOneWidget);
      expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
    });

    testWidgets('Loads prompts correctly when valid ?writer=e01 is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionScreen(
            initialUri: Uri.parse('https://example.com/#/?writer=e01'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should display top bar with e01 writer badge and 1 / 50 progress
      expect(find.text('الكاتب e01'), findsOneWidget);
      expect(find.text('1 / 50'), findsOneWidget);
      expect(find.text('إرسال والتالي'), findsOneWidget);
    });
  });
}
