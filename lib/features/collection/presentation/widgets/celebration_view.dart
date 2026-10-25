import 'package:flutter/material.dart';

/// Celebration view displayed upon concluding a batch (e.g. 15/15 for crowd or 130/130 for core).
class CelebrationView extends StatelessWidget {
  final String writerId;
  final String tier;
  final int totalSubmitted;
  final VoidCallback onContributeMore;
  final VoidCallback? onReviewPrompts;

  const CelebrationView({
    super.key,
    required this.writerId,
    required this.tier,
    required this.totalSubmitted,
    required this.onContributeMore,
    this.onReviewPrompts,
  });

  @override
  Widget build(BuildContext context) {
    final isCrowd = tier == 'crowd_15';

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
                const Text(
                  'تم تسجيل الحزمة بنجاح',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle description
                Text(
                  isCrowd
                      ? 'مساهمتكم الكريمة بكتابة $totalSubmitted آية تُسهم مباشرة في تدريب ونقاء أول مصحح ذكي لخط اليد للقرآن الكريم برواية حفص عن عاصم.'
                      : 'أتممتم بنجاح كامل جلسة المعايرة والتدريب ($totalSubmitted آية). جزاكم الله خير الجزاء ونفع بكم.',
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
                      Expanded(child: _buildStatItem('الحزمة المكتملة', writerId)),
                      Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                      Expanded(child: _buildStatItem('الآيات المكتوبة', '$totalSubmitted')),
                      Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                      Expanded(child: _buildStatItem('الحالة', 'مرفوعة 100%')),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Prominent "Contribute 15 More" Action Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: onContributeMore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065F46),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                    label: Text(
                      isCrowd
                          ? 'المساهمة في 15 آية إضافية'
                          : 'المتابعة لحزمة إضافية',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamilyFallback: ['Amiri', 'Traditional Arabic'],
                      ),
                    ),
                  ),
                ),

                if (onReviewPrompts != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onReviewPrompts,
                    child: const Text(
                      'مراجعة الآيات السابقة',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
            fontSize: 16,
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
