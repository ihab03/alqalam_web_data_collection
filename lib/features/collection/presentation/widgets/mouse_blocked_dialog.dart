import 'package:flutter/material.dart';

/// Polite dialog displayed when desktop mouse input is detected (Section 3.2).
Future<void> showMouseBlockedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: const [
              Icon(Icons.touch_app_rounded, color: Color(0xFFD97706), size: 28),
              SizedBox(width: 8),
              Text(
                'تنبيه: يلزم استخدام القلم أو اللمس',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: const Text(
            '⚠️ يرجى فتح الرابط على جهاز لوحي (iPad أو Android Tablet) باستخدام قلم الشاشة أو اللمس بالأصبع.\n\nتم تعطيل الرسم بالفأرة (Mouse) لضمان دقة ونقاء بيانات التدريب لنماذج الذكاء الاصطناعي.',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF334155),
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF065F46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'حسناً، فهمت',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    },
  );
}
