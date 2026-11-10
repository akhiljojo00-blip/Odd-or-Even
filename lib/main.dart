import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'app/router.dart';
import 'core/theme/game_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if credentials are provided via dart-define
  const supabaseUrl = AppConfig.supabaseUrl;
  const supabaseAnonKey = AppConfig.supabaseAnonKey;

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialization skipped or failed: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: OddOrEvenApp(),
    ),
  );
}

class OddOrEvenApp extends StatelessWidget {
  const OddOrEvenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.isStaging ? 'Odd or Even [STAGING]' : 'Odd or Even',
      debugShowCheckedModeBanner: false,
      theme: GameTheme.darkTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        if (!AppConfig.isStaging) return child ?? const SizedBox.shrink();
        return Banner(
          message: 'STAGING',
          location: BannerLocation.topEnd,
          color: const Color(0xFFFF9800),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
