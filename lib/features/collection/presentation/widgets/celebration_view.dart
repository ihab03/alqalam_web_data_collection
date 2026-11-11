import 'package:flutter/material.dart';

/// Celebration view displayed upon concluding an assigned writer slot
/// (50 for EVAL, 15 for EVAL_SHORT, 120 for TRAIN).
class CelebrationView extends StatelessWidget {
  final String writerId;
  final String tier;
  final String? assignment;
  final int totalSubmitted;
  final VoidCallback? onReviewPrompts;

  const CelebrationView({
    super.key,
    required this.writerId,
    required this.tier,
    this.assignment,
    required this.totalSubmitted,
    this.onReviewPrompts,
  });

  String get _assignmentTitle {
    if (assignment == 'EVAL' || tier == 'eval_50') {
      return 'جلسة التقييم (EVAL)';
    } else if (assignment == 'EVAL_SHORT' || tier == 'eval_short_15') {
      return 'جلسة التقييم السريعة (EVAL_SHORT)';
    } else if (assignment == 'TRAIN' || tier == 'train_120') {
      return 'جلسة التدريب (TRAIN)';
    }
    return 'جلسة الكتابة';
  }

  String get _descriptionText {
    if (assignment == 'EVAL' || tier == 'eval_50') {
      return 'أتممتم بنجاح كامل جلسة التقييم ($totalSubmitted آية). مساهمتكم الكريمة تُسهم مباشرة في قياس دقة ونقاء نموذج الخط القرآني برواية حفص عن عاصم. جزاكم الله خير الجزاء ونفع بكم.';
    } else if (assignment == 'EVAL_SHORT' || tier == 'eval_short_15') {
      return 'أتممتم بنجاح كامل جلسة التقييم السريعة ($totalSubmitted آية). مساهمتكم الكريمة تُسهم مباشرة في قياس دقة ونقاء نموذج الخط القرآني برواية حفص عن عاصم. جزاكم الله خير الجزاء ونفع بكم.';
    } else if (assignment == 'TRAIN' || tier == 'train_120') {
      return 'أتممتم بنجاح كامل جلسة التدريب الموسعة ($totalSubmitted آية). مساهمتكم الكريمة تُسهم مباشرة في تدريب وتطوير أول نموذج ذكي للخط القرآني برواية حفص عن عاصم. جزاكم الله خير الجزاء ونفع بكم.';
    }
    return 'أتممتم بنجاح كامل مهام الكاتب ($totalSubmitted آية) وحُفظت مساهمتكم في قاعدة البيانات بأمان. جزاكم الله خير الجزاء ونفع بكم.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C065F46),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration Icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF059669),
                      size: 54,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Main Greeting
                const Text(
                  'جزاكم الله خيراً!',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF065F46),
                    fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'تم إكمال $_assignmentTitle بنجاح',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle description
                Text(
                  _descriptionText,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFF475569),
                    fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                  ),
                ),
                const SizedBox(height: 24),

                // Session Summary Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(child: _buildStatItem('الكاتب المعين', writerId)),
                      Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                      Expanded(child: _buildStatItem('النوع', assignment ?? tier)),
                      Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                      Expanded(child: _buildStatItem('الآيات المكتملة', '$totalSubmitted')),
                      Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                      Expanded(child: _buildStatItem('الحالة', 'مرفوعة 100%')),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                if (onReviewPrompts != null)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: onReviewPrompts,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF065F46),
                        side: const BorderSide(color: Color(0xFF059669), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.menu_book_rounded, size: 20),
                      label: const Text(
                        'مراجعة الآيات السابقة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
