import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/router.dart';
import 'core/theme/game_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if credentials are provided via dart-define
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
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
      title: 'Odd or Even',
      debugShowCheckedModeBanner: false,
      theme: GameTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
