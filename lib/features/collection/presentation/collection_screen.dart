import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../canvas/domain/canvas_line_recorder.dart';
import '../../canvas/presentation/widgets/handwriting_canvas_widget.dart';
import '../data/manifest_repository.dart';
import '../data/session_manager.dart';
import '../data/upload_service.dart';
import '../domain/prompt_models.dart';
import 'widgets/celebration_view.dart';
import 'widgets/mouse_blocked_dialog.dart';
import 'widgets/notice_banner_widget.dart';
import 'widgets/top_bar_widget.dart';

class CollectionScreen extends StatefulWidget {
  final Uri? initialUri;

  const CollectionScreen({super.key, this.initialUri});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final SessionManager _sessionManager;
  late final UploadService _uploadService;

  ManifestData? _manifest;
  bool _isLoading = true;
  String? _errorMessage;

  String _writerId = 'c001';
  String _tier = 'crowd_15';
  List<PromptItem> _prompts = [];
  int _currentIndex = 0;
  bool _isCelebration = false;
  bool _isUploading = false;

  List<CanvasLineRecorder> _lineRecorders = [];

  PromptItem? get _currentPrompt =>
      (_prompts.isNotEmpty && _currentIndex < _prompts.length)
      ? _prompts[_currentIndex]
      : null;

  @override
  void initState() {
    super.initState();
    _sessionManager = SessionManager();
    _uploadService = UploadService();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final manifest = await ManifestRepository.loadManifest();
      final uri = widget.initialUri ?? Uri.base;
      final session = _sessionManager.resolveSession(uri, manifest);

      _manifest = manifest;
      _writerId = session.writerId;
      _tier = session.tier;
      _prompts = session.prompts;
      _currentIndex = session.initialPromptIndex;

      // Check if all prompts were already finished prior to opening
      final allDone =
          _prompts.isNotEmpty &&
          _prompts.every((p) => _sessionManager.isPromptCompleted(p.promptId));
      _isCelebration = allDone;

      _setupLineRecordersForCurrentPrompt();

      setState(() {
        _isLoading = false;
      });

      if (!_sessionManager.hasCustomContributorName && !_isCelebration) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_sessionManager.hasCustomContributorName) {
            _showContributorNameDialog(isMandatory: true);
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل بيانات المصحف الشريف والمهام: $e';
      });
    }
  }

  void _setupLineRecordersForCurrentPrompt() {
    for (final rec in _lineRecorders) {
      rec.dispose();
    }
    _lineRecorders = [];

    final prompt = _currentPrompt;
    if (prompt == null) return;

    final lineCount = math.max(1, prompt.numCanvasLines);
    _lineRecorders = List.generate(
      lineCount,
      (index) => CanvasLineRecorder(lineIndex: index),
    );
  }

  @override
  void dispose() {
    for (final rec in _lineRecorders) {
      rec.dispose();
    }
    super.dispose();
  }

  /// Undo the last stroke across active line bands.
  void _handleQuickUndo() {
    for (int i = _lineRecorders.length - 1; i >= 0; i--) {
      if (_lineRecorders[i].canUndo) {
        _lineRecorders[i].undo();
        setState(() {});
        return;
      }
    }
  }

  /// Clear all canvas lines.
  void _handleClearSlate() {
    for (final rec in _lineRecorders) {
      rec.clear();
    }
    setState(() {});
  }

  /// Validates content and triggers immediate rasterization & upload.
  Future<void> _handleSubmitAndNext() async {
    final prompt = _currentPrompt;
    if (prompt == null || _isUploading) return;

    if (!_validateCanWrite()) return;

    // 1. Validation: Ensure canvas is not empty (at least 1 stroke with >= 2 points)
    final bool hasValidStroke = _lineRecorders.any(
      (rec) => rec.hasValidContent,
    );
    if (!hasValidStroke) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✍️ يرجى كتابة النص القرآني المعروض على اللوح قبل المتابعة.',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
            ),
          ),
          backgroundColor: Color(0xFFB45309),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final mediaQuery = MediaQuery.of(context);
      final double dpr = mediaQuery.devicePixelRatio;
      // Logical width constrained to max 840px
      final double logicalWidth = math.min(mediaQuery.size.width - 32.0, 840.0);
      const double logicalHeight = 108.0;

      // 2. Rasterize PNGs and issue immediate multipart request
      final result = await _uploadService.submitAndUploadPrompt(
        promptItem: prompt,
        lineRecorders: _lineRecorders,
        logicalWidth: logicalWidth,
        logicalHeight: logicalHeight,
        dpr: dpr,
        contributorKey: _sessionManager.contributorDirectoryKey,
        contributorName: _sessionManager.contributorName,
        contributorUid: _sessionManager.contributorUid,
      );

      // Mark completed in session manager
      _sessionManager.markPromptCompleted(prompt.promptId);

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✓ تم تسجيل ورفع الآية الكريمة بنجاح إلى السحابة.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
              ),
            ),
            backgroundColor: Color(0xFF065F46),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1400),
          ),
        );
      } else if (result.cachedLocally) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ تعذر الاتصال المباشر (${result.errorMessage ?? "غير متصل"}). تم حفظ التسجيل في المتصفح محلياً بأمان.',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
              ),
            ),
            backgroundColor: const Color(0xFFB45309),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // 3. Instantly advance to seq_index + 1
      if (_currentIndex + 1 < _prompts.length) {
        setState(() {
          _currentIndex++;
          _isUploading = false;
        });
        _setupLineRecordersForCurrentPrompt();
      } else {
        // Concluded all prompts in batch! Show Celebration screen
        setState(() {
          _isCelebration = true;
          _isUploading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء معالجة الصورة: $e',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  /// Handles "Contribute 15 More" flow.
  void _handleContributeMore() {
    if (_manifest == null) return;

    final nextBatchId = _sessionManager.claimNextCrowdBatch(
      _manifest!,
      _writerId,
    );
    final prompts = _manifest!.getPromptsForWriter(nextBatchId) ?? [];

    setState(() {
      _writerId = nextBatchId;
      _prompts = prompts;
      _currentIndex = 0;
      _isCelebration = false;
    });

    _setupLineRecordersForCurrentPrompt();
  }

  bool _isNameDialogShowing = false;

  /// Validates whether the user can start writing / typing.
  /// If no name has been entered, opens the compulsory name dialog and returns false.
  bool _validateCanWrite() {
    if (!_sessionManager.hasCustomContributorName) {
      _showContributorNameDialog(isMandatory: true);
      return false;
    }
    return true;
  }

  /// Dialog allowing the user to view, customize, or mandatorily enter their contributor display name.
  Future<void> _showContributorNameDialog({bool isMandatory = false}) async {
    if (_isNameDialogShowing || !mounted) return;
    _isNameDialogShowing = true;

    final currentName = _sessionManager.contributorName;
    final controller = TextEditingController(
      text: currentName == 'anonymous' ? '' : currentName,
    );
    String? validationError;

    await showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void submitName() {
            final newName = controller.text.trim();
            if (newName.isEmpty) {
              setDialogState(() {
                validationError = 'يرجى إدخال اسمك قبل البدء بالكتابة';
              });
              return;
            }
            if (newName.toLowerCase() == 'anonymous') {
              setDialogState(() {
                validationError = 'يرجى إدخال اسمك الحقيقي';
              });
              return;
            }
            final sanitized = SessionManager.sanitizeContributorName(newName);
            if (sanitized.isEmpty || sanitized == 'anonymous') {
              setDialogState(() {
                validationError = 'يرجى إدخال اسم صحيح يحتوي على حروف';
              });
              return;
            }

            setState(() {
              _sessionManager.contributorName = newName;
            });
            Navigator.of(ctx).pop();
          }

          return PopScope(
            canPop: !isMandatory,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF065F46),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'اسم الكاتب / المساهم',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                      ),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isMandatory
                          ? 'مرحباً بك! يرجى إدخال اسمك الكريم قبل البدء بالكتابة لحفظ وتوثيق مساهمتك باسمك في قاعدة البيانات:'
                          : 'يمكنك تعديل اسمك لحفظ المساهمات في مجلد خاص بك باسمك في قاعدة البيانات:',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'الاسم',
                        hintText: 'أدخل اسمك باللغة الانجليزية',
                        errorText: validationError,
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: Color(0xFF065F46),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF065F46),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) {
                        if (validationError != null) {
                          setDialogState(() {
                            validationError = null;
                          });
                        }
                      },
                      onSubmitted: (_) => submitName(),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              actions: [
                if (!isMandatory)
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('إلغاء'),
                  ),
                FilledButton.icon(
                  onPressed: submitName,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    isMandatory ? 'بدء الكتابة' : 'حفظ التعديل',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF065F46),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    _isNameDialogShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF065F46)),
              ),
              SizedBox(height: 16),
              Text(
                'جاري تحميل بنك الآيات القرآني...',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.bold,
                  fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _initializeData,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Celebration Screen
    if (_isCelebration) {
      return Scaffold(
        body: SafeArea(
          child: CelebrationView(
            writerId: _writerId,
            tier: _tier,
            totalSubmitted: _prompts.length,
            onContributeMore: _handleContributeMore,
            onReviewPrompts: () {
              setState(() {
                _isCelebration = false;
                _currentIndex = 0;
              });
              _setupLineRecordersForCurrentPrompt();
            },
          ),
        ),
      );
    }

    final prompt = _currentPrompt;
    if (prompt == null) {
      return const Scaffold(body: Center(child: Text('لا توجد مهام متاحة')));
    }

    final anyCanUndo = _lineRecorders.any((r) => r.canUndo);
    final anyNotEmpty = _lineRecorders.any((r) => !r.isEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: CollectionTopBar(
          writerId: _writerId,
          tier: _tier,
          currentIndex: _currentIndex,
          totalCount: _prompts.length,
          currentPrompt: prompt,
          contributorName: _sessionManager.contributorName,
          onEditContributorName: () => _showContributorNameDialog(
            isMandatory: !_sessionManager.hasCustomContributorName,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Surah & Ayah Reference Chip
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        prompt.referenceLabelArabic,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                          fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Intentional Error Warning Banner (Pack D) - Section 2
                  IntentionalErrorBanner(noticeText: prompt.uiNoticeAr),

                  // Quran Prompt Text Display
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 16.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          prompt.displayTextUthmani,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 30.0,
                            fontWeight: FontWeight.w700,
                            height: 1.8,
                            color: Color(0xFF0F172A),
                            fontFamilyFallback: [
                              'Amiri',
                              'Traditional Arabic',
                              'Scheherazade New',
                            ],
                          ),
                        ),
                        if (prompt.errorMeta != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'نص الإملاء المطلوب: ${prompt.writtenImlai}',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 14.0,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Writing Canvas Area (Section 3.1 & Multi-Line Support)
                  ..._buildCanvasBands(prompt),

                  const SizedBox(height: 16),

                  // Bottom Action Toolbar (Quick Undo, Clear, Submit & Next)
                  _buildActionBar(anyCanUndo, anyNotEmpty),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds 1, 2, or 3 separate 108px canvas bands with 36px inter-line spacers (Section 3.1).
  List<Widget> _buildCanvasBands(PromptItem prompt) {
    final List<Widget> bands = [];
    final int lineCount = _lineRecorders.length;

    for (int i = 0; i < lineCount; i++) {
      final linePromptItem = (i < prompt.linePrompts.length)
          ? prompt.linePrompts[i]
          : null;

      final label = lineCount > 1 ? 'السطر ${i + 1}' : null;
      final linePromptText = linePromptItem?.displayTextUthmani;

      bands.add(
        HandwritingCanvasBandWidget(
          key: ValueKey('band_${prompt.promptId}_line_$i'),
          recorder: _lineRecorders[i],
          maxWidth: 840.0,
          height: 108.0,
          lineLabel: label,
          linePromptText: lineCount > 1 ? linePromptText : null,
          onMouseBlocked: () => showMouseBlockedDialog(context),
          onValidateCanWrite: _validateCanWrite,
          onStrokeEnded: () => setState(() {}),
        ),
      );

      // Add 36px inter-line spacer between stacked lines
      if (i < lineCount - 1) {
        bands.add(const SizedBox(height: 36.0));
      }
    }

    return bands;
  }

  /// Builds the persistent Action Bar with Quick Undo, Clear Slate, and Submit & Next.
  Widget _buildActionBar(bool anyCanUndo, bool anyNotEmpty) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Submit & Next Button (Primary action)
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _handleSubmitAndNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF065F46),
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text(
                  _isUploading ? 'جاري الإرسال...' : 'إرسال والتالي',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Quick Undo Button
          IconButton.outlined(
            onPressed: anyCanUndo && !_isUploading ? _handleQuickUndo : null,
            tooltip: 'تراجع (Undo)',
            icon: const Icon(Icons.undo_rounded),
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(width: 8),

          // Clear Slate Button
          IconButton.outlined(
            onPressed: anyNotEmpty && !_isUploading ? _handleClearSlate : null,
            tooltip: 'مسح اللوح (Clear)',
            icon: const Icon(Icons.delete_outline_rounded),
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF991B1B),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}
