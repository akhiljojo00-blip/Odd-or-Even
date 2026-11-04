import 'package:go_router/go_router.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/matchmaking/presentation/screens/matchmaking_screen.dart';
import '../features/offline/presentation/screens/offline_gameplay_screen.dart';
import '../features/offline/presentation/screens/offline_result_screen.dart';
import '../features/offline/presentation/screens/offline_setup_screen.dart';
import '../features/online/presentation/screens/online_gameplay_screen.dart';
import '../features/online/presentation/screens/online_lobby_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/rooms/presentation/screens/room_screen.dart';
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
      path: '/matchmaking',
      builder: (context, state) => const MatchmakingScreen(),
    ),
    GoRoute(
      path: '/room/:id',
      builder: (context, state) {
        final roomId = state.pathParameters['id'] ?? '';
        final code = state.uri.queryParameters['code'] ?? '';
        final isHost = state.uri.queryParameters['isHost'] == 'true';
        return RoomScreen(
          roomId: roomId,
          roomCode: code,
          isHost: isHost,
        );
      },
    ),
    GoRoute(
      path: '/online-play/:id',
      builder: (context, state) {
        final matchId = state.pathParameters['id'] ?? '';
        return OnlineGameplayScreen(matchId: matchId);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
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
