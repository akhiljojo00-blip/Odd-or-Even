import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/core/widgets/creator_footer.dart';
import 'package:odd_or_even/features/game/domain/engine/odd_or_even_engine.dart';
import 'package:odd_or_even/features/game/domain/models/match_config.dart';
import 'package:odd_or_even/features/game/domain/models/player_info.dart';
import 'package:odd_or_even/features/game/presentation/widgets/number_pad.dart';
import 'package:odd_or_even/features/game/presentation/widgets/scoreboard_card.dart';
import 'package:odd_or_even/features/history/presentation/screens/history_screen.dart';
import 'package:odd_or_even/features/home/presentation/screens/home_screen.dart';
import 'package:odd_or_even/features/matchmaking/presentation/screens/matchmaking_screen.dart';
import 'package:odd_or_even/features/offline/presentation/screens/offline_result_screen.dart';
import 'package:odd_or_even/features/offline/presentation/screens/offline_setup_screen.dart';
import 'package:odd_or_even/features/profile/presentation/screens/profile_screen.dart';
import 'package:odd_or_even/features/rooms/presentation/screens/room_screen.dart';
import 'package:odd_or_even/features/settings/presentation/screens/settings_screen.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('NumberPad displays buttons 1 through 10 and handles selection', (tester) async {
      int? selected;
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NumberPad(
                  selectedNumber: selected,
                  onNumberSelected: (n) => setState(() => selected = n),
                  onConfirm: () => confirmed = true,
                );
              },
            ),
          ),
        ),
      );

      // Verify all 10 buttons are present
      for (int i = 1; i <= 10; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Tap button 7
      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();

      expect(selected, 7);
      expect(find.text('LOCK IN NUMBER 7'), findsOneWidget);

      // Tap Confirm
      await tester.tap(find.text('LOCK IN NUMBER 7'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    testWidgets('ScoreboardCard renders 1st innings score and overs correctly', (tester) async {
      final state = OddOrEvenEngine.initializeMatch(
        config: const MatchConfig(overs: 2),
        player1: const PlayerInfo(id: 'p1', name: 'Alice'),
        player2: const PlayerInfo(id: 'p2', name: 'Bob'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreboardCard(matchState: state),
          ),
        ),
      );

      expect(find.text('1ST INNINGS'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // 0 runs
      expect(find.text('OVERS: 0.0 / 2.0'), findsOneWidget);
    });

    testWidgets('HomeScreen renders mode options and branding', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      expect(find.text('ODD OR EVEN'), findsOneWidget);
      expect(find.text('PASS & PLAY'), findsOneWidget);
      expect(find.text('ONLINE ROOMS'), findsOneWidget);
      expect(find.text('QUICK MATCH'), findsOneWidget);
    });

    testWidgets('MatchmakingScreen renders finding opponent radar and cancel button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MatchmakingScreen(),
          ),
        ),
      );

      expect(find.text('FINDING OPPONENT'), findsOneWidget);
      expect(find.text('CANCEL SEARCH'), findsOneWidget);

      // Cleanly cancel search and dispose timers
      await tester.tap(find.text('CANCEL SEARCH'));
      await tester.pump();
    });

    testWidgets('RoomScreen renders room code and match settings', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RoomScreen(
              roomId: 'room-123',
              roomCode: 'CRIC99',
              isHost: true,
            ),
          ),
        ),
      );

      expect(find.text('CRIC99'), findsOneWidget);
      expect(find.text('SHARE ROOM CODE'), findsOneWidget);
      expect(find.text('HOST (YOU)'), findsOneWidget);
      expect(find.text('MATCH SETTINGS AGREEMENT'), findsOneWidget);
      expect(find.text('CONFIRM SETTINGS'), findsOneWidget);
    });

    testWidgets('ProfileScreen renders career statistics and display name field', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // Settle async init
      await tester.pump();

      expect(find.text('PLAYER PROFILE'), findsOneWidget);
      expect(find.text('CAREER STATISTICS'), findsOneWidget);
      expect(find.text('MATCHES'), findsOneWidget);
      expect(find.text('WINS'), findsOneWidget);
      expect(find.text('LOSSES'), findsOneWidget);
      expect(find.text('TIED'), findsOneWidget);
      expect(find.text('SAVE PROFILE'), findsOneWidget);
      expect(find.byType(CreatorFooter), findsOneWidget);
    });

    testWidgets('OfflineSetupScreen renders match configuration and CreatorFooter', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OfflineSetupScreen(),
          ),
        ),
      );

      expect(find.text('MATCH CONFIGURATION'), findsOneWidget);
      expect(find.text('PLAYERS (PASS & PLAY)'), findsOneWidget);
      expect(find.text('START MATCH'), findsOneWidget);
      expect(find.byType(CreatorFooter), findsOneWidget);
    });

    testWidgets('HistoryScreen renders match history and CreatorFooter', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      expect(find.text('MATCH HISTORY'), findsOneWidget);
      expect(find.byType(CreatorFooter), findsOneWidget);
    });

    testWidgets('SettingsScreen renders audio/haptics settings and CreatorFooter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('Sound Effects'), findsOneWidget);
      expect(find.text('Haptic Feedback'), findsOneWidget);
      expect(find.byType(CreatorFooter), findsOneWidget);
    });

    testWidgets('OfflineResultScreen renders safely without crash and shows CreatorFooter', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OfflineResultScreen(),
          ),
        ),
      );

      expect(find.byType(OfflineResultScreen), findsOneWidget);
      expect(find.byType(CreatorFooter), findsOneWidget);
    });
  });
}
