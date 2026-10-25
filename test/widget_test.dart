import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alqalam_web_data_collection/core/storage/storage_service.dart';
import 'package:alqalam_web_data_collection/features/canvas/domain/canvas_line_recorder.dart';
import 'package:alqalam_web_data_collection/features/canvas/presentation/widgets/handwriting_canvas_widget.dart';
import 'package:alqalam_web_data_collection/features/collection/data/manifest_repository.dart';
import 'package:alqalam_web_data_collection/features/collection/data/session_manager.dart';
import 'package:alqalam_web_data_collection/features/collection/domain/prompt_models.dart';
import 'package:alqalam_web_data_collection/features/collection/presentation/widgets/celebration_view.dart';
import 'package:alqalam_web_data_collection/features/collection/presentation/widgets/notice_banner_widget.dart';
import 'package:alqalam_web_data_collection/features/collection/presentation/widgets/top_bar_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late SessionManager sessionManager;
  late ManifestData mockManifest;

  setUp(() {
    storage = StorageService.instance;
    storage.clearMemoryFallback();
    sessionManager = SessionManager(storage: storage);

    // Build mock manifest data
    final Map<String, List<PromptItem>> writers = {};
    for (final w in ['w01', 'w02', 'w03', 'w04']) {
      writers[w] = List.generate(
        130,
        (i) => PromptItem(
          seqIndex: i + 1,
          promptId: '${w}_${(i + 1).toString().padLeft(3, '0')}',
          writerId: w,
          tier: 'core_130',
          packType: i < 25 ? 'shared_core' : 'disjoint_coverage',
          isTrainingEligible: true,
          numCanvasLines: 1,
          surah: 1,
          ayahStart: 1,
          ayahEnd: 1,
          gStart: 1,
          gEnd: 4,
          displayTextUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
          writtenImlai: 'بسم الله الرحمن الرحيم',
          canonicalImlai: 'بسم الله الرحمن الرحيم',
          linePrompts: const [],
          rawJson: {'prompt_id': '${w}_${i + 1}'},
        ),
      );
    }
    for (int c = 1; c <= 100; c++) {
      final cid = 'c${c.toString().padLeft(3, '0')}';
      writers[cid] = List.generate(
        15,
        (i) => PromptItem(
          seqIndex: i + 1,
          promptId: '${cid}_${(i + 1).toString().padLeft(3, '0')}',
          writerId: cid,
          tier: 'crowd_15',
          packType: i < 3 ? 'shared_core' : (i < 12 ? 'disjoint_coverage' : (i == 12 ? 'multiline_cross_ayah' : 'intentional_error_eval')),
          isTrainingEligible: i < 13,
          numCanvasLines: i == 12 ? 2 : 1,
          surah: 1,
          ayahStart: 1,
          ayahEnd: 1,
          gStart: 1,
          gEnd: 4,
          displayTextUthmani: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ',
          writtenImlai: 'الحمد لله رب العالمين',
          canonicalImlai: 'الحمد لله رب العالمين',
          linePrompts: const [],
          uiNoticeAr: i >= 13 ? '🎯 اختبار دقة للذكاء الاصطناعي' : null,
          rawJson: {'prompt_id': '${cid}_${i + 1}'},
        ),
      );
    }

    mockManifest = ManifestData(metadata: {}, writers: writers);
  });

  group('SessionManager Two-Tier Routing Tests', () {
    test('Tier 1: ?writer=w01 routes to w01 and core_130 tier', () {
      final uri = Uri.parse('https://example.com/#/?writer=w01');
      final result = sessionManager.resolveSession(uri, mockManifest);

      expect(result.writerId, 'w01');
      expect(result.tier, 'core_130');
      expect(result.prompts.length, 130);
      expect(result.initialPromptIndex, 0);
    });

    test('Tier 1: auto-resumes at the lowest incomplete seq_index', () {
      // Mark prompts 1, 2, 3 complete
      sessionManager.markPromptCompleted('w02_001');
      sessionManager.markPromptCompleted('w02_002');
      sessionManager.markPromptCompleted('w02_003');

      final uri = Uri.parse('https://example.com/#/?writer=w02');
      final result = sessionManager.resolveSession(uri, mockManifest);

      expect(result.writerId, 'w02');
      expect(result.initialPromptIndex, 3); // 0-indexed, so seq_index = 4
    });

    test('Tier 2: no writer param auto-claims first unclaimed crowd batch (c001)', () {
      final uri = Uri.parse('https://example.com/#/');
      final result = sessionManager.resolveSession(uri, mockManifest);

      expect(result.writerId, 'c001');
      expect(result.tier, 'crowd_15');
      expect(result.prompts.length, 15);
      expect(result.initialPromptIndex, 0);
    });

    test('Tier 2: marks batch complete and claims next batch (c002)', () {
      final nextBatch = sessionManager.claimNextCrowdBatch(mockManifest, 'c001');
      expect(nextBatch, 'c002');
      expect(storage.getItem('hafs_batch_done_c001'), 'true');
      expect(storage.getItem('hafs_current_crowd_batch'), 'c002');
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

    testWidgets('CelebrationView displays congratulations and Contribute 15 More button', (tester) async {
      bool contributeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelebrationView(
              writerId: 'c001',
              tier: 'crowd_15',
              totalSubmitted: 15,
              onContributeMore: () {
                contributeTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('جزاكم الله خيراً!'), findsOneWidget);
      expect(find.text('تم تسجيل الحزمة بنجاح'), findsOneWidget);
      expect(find.text('المساهمة في 15 آية إضافية'), findsOneWidget);

      await tester.tap(find.text('المساهمة في 15 آية إضافية'));
      expect(contributeTapped, isTrue);
    });

    testWidgets('CollectionTopBar renders badges and progress correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(74.0),
              child: CollectionTopBar(
                writerId: 'c001',
                tier: 'crowd_15',
                currentIndex: 13,
                totalCount: 15,
                currentPrompt: mockManifest.writers['c001']![13],
              ),
            ),
          ),
        ),
      );

      expect(find.text('الحزمة c001'), findsOneWidget);
      expect(find.text('14 / 15'), findsOneWidget);
      expect(find.text('د: اختبار الدقة الذكي 🎯'), findsOneWidget);
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
  });
}
