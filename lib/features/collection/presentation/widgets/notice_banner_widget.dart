import 'package:flutter/material.dart';

/// Intentional Error Warning Banner for Pack D items per Section 2 of FLUTTER_COLLECTION_SPEC.md.
///
/// Prevents Hafiz / scribes from instinctively auto-correcting intentional mutations.
class IntentionalErrorBanner extends StatelessWidget {
  final String? noticeText;

  const IntentionalErrorBanner({
    super.key,
    required this.noticeText,
  });

  @override
  Widget build(BuildContext context) {
    if (noticeText == null || noticeText!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08FCD34D),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB45309),
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              noticeText!,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Color(0xFF78350F),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                height: 1.45,
                fontFamilyFallback: ['Amiri', 'Traditional Arabic', 'Arial'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
