import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/game/domain/engine/odd_or_even_engine.dart';
import 'package:odd_or_even/features/game/domain/models/match_config.dart';
import 'package:odd_or_even/features/game/domain/models/player_info.dart';
import 'package:odd_or_even/features/game/presentation/widgets/number_pad.dart';
import 'package:odd_or_even/features/game/presentation/widgets/scoreboard_card.dart';
import 'package:odd_or_even/features/home/presentation/screens/home_screen.dart';

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
  });
}
