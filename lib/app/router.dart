import 'package:go_router/go_router.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/offline/presentation/screens/offline_gameplay_screen.dart';
import '../features/offline/presentation/screens/offline_result_screen.dart';
import '../features/offline/presentation/screens/offline_setup_screen.dart';
import '../features/online/presentation/screens/online_lobby_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/offline-setup',
      builder: (context, state) => const OfflineSetupScreen(),
    ),
    GoRoute(
      path: '/offline-play',
      builder: (context, state) => const OfflineGameplayScreen(),
    ),
    GoRoute(
      path: '/offline-result',
      builder: (context, state) => const OfflineResultScreen(),
    ),
    GoRoute(
      path: '/online-lobby',
      builder: (context, state) => const OnlineLobbyScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
