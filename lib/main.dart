import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/collection/presentation/collection_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://ezfuuosbmjxvgesbswfa.supabase.co',
      // ignore: deprecated_member_use
      anonKey: 'sb_publishable_evnrnA2UlIitRuteItJeag_9OUtvCPV',
    );
  } catch (e) {
    debugPrint('Supabase initialization note: $e');
  }

  runApp(const AlQalamCollectionApp());
}

/// Root application widget for the AlQalam Web Data Collection Portal.
class AlQalamCollectionApp extends StatelessWidget {
  const AlQalamCollectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بوابة جمع بيانات الخط القرآني - القلم',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const CollectionScreen(),
    );
  }
}
