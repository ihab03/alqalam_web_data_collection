import 'package:flutter/material.dart';
import '../../domain/prompt_models.dart';

/// Responsive Top Bar displaying writer/batch identity, progress, and pack metadata.
class CollectionTopBar extends StatelessWidget {
  final String writerId;
  final String tier;
  final int currentIndex; // 0-indexed
  final int totalCount;
  final PromptItem? currentPrompt;
  final int pendingUploadsCount;

  const CollectionTopBar({
    super.key,
    required this.writerId,
    required this.tier,
    required this.currentIndex,
    required this.totalCount,
    this.currentPrompt,
    this.pendingUploadsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isCore = tier == 'core_130';
    final seqNumber = currentIndex + 1;
    final progress = totalCount > 0 ? (seqNumber / totalCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                // Writer / Batch Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCore ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCore ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCore ? Icons.verified_user_rounded : Icons.groups_rounded,
                        size: 16,
                        color: isCore ? const Color(0xFF1D4ED8) : const Color(0xFF047857),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCore ? 'الكاتب $writerId' : 'الحزمة $writerId',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCore ? const Color(0xFF1E40AF) : const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Pack Type Badge
                if (currentPrompt != null)
                  _buildPackBadge(currentPrompt!.packType),

                const Spacer(),

                // Pending uploads badge (if any)
                if (pendingUploadsCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_queue_rounded,
                            size: 14, color: Color(0xFFB45309)),
                        const SizedBox(width: 4),
                        Text(
                          '$pendingUploadsCount معلق',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Progress Counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '$seqNumber / $totalCount',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Linear Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackBadge(String packType) {
    Color bg;
    Color border;
    Color text;
    String label;

    switch (packType) {
      case 'shared_core':
        bg = const Color(0xFFECFDF5);
        border = const Color(0xFFA7F3D0);
        text = const Color(0xFF065F46);
        label = 'أ: المعايرة الأساسية';
        break;
      case 'disjoint_coverage':
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        text = const Color(0xFF1E40AF);
        label = 'ب: التغطية المتفرقة';
        break;
      case 'multiline_cross_ayah':
        bg = const Color(0xFFFAF5FF);
        border = const Color(0xFFE9D5FF);
        text = const Color(0xFF6B21A8);
        label = 'ج: أسطر متعددة';
        break;
      case 'intentional_error_eval':
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFFDE68A);
        text = const Color(0xFF92400E);
        label = 'د: اختبار الدقة الذكي 🎯';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFE2E8F0);
        text = const Color(0xFF475569);
        label = packType;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}
