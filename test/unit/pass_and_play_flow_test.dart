import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/game/domain/models/game_enums.dart';
import 'package:odd_or_even/features/game/domain/models/match_config.dart';
import 'package:odd_or_even/features/history/data/match_history_repository.dart';
import 'package:odd_or_even/features/offline/presentation/controllers/offline_game_controller.dart';

class FakeMatchHistoryRepository extends MatchHistoryRepository {
  final List<dynamic> savedMatches = [];

  @override
  Future<void> saveMatchRecord(dynamic match) async {
    savedMatches.add(match);
  }
}

void main() {
  group('Pass and Play Complete Flow Test', () {
    late FakeMatchHistoryRepository fakeRepo;
    late OfflineGameNotifier notifier;

    setUp(() {
      fakeRepo = FakeMatchHistoryRepository();
      notifier = OfflineGameNotifier(fakeRepo);
    });

    test('Full 2-innings match flow with privacy handoffs and rematch', () {
      // 1. Start match
      notifier.startNewGame(
        config: const MatchConfig(overs: null, seriesTargetPoints: 2),
        player1Name: 'Alice',
        player2Name: 'Bob',
      );

      var state = notifier.state;
      expect(state.match.phase, MatchPhase.tossInput);
      expect(state.waitingForHandoff, isFalse);

      final aliceParity = state.match.player1.parity!;

      // 2. Alice submits toss number 4
      notifier.submitChoice(playerId: 'p1', choice: 4);
      state = notifier.state;
      expect(state.waitingForHandoff, isTrue);
      expect(state.p1PendingChoice, 4);

      // 3. Acknowledge handoff to Bob
      notifier.acknowledgeHandoff();
      expect(notifier.state.waitingForHandoff, isFalse);

      // 4. Bob submits toss number:
      // If Alice is ODD, we want sum to be odd (e.g. 4 + 3 = 7) so Alice wins
      // If Alice is EVEN, we want sum to be even (e.g. 4 + 4 = 8) so Alice wins
      final bobTossNumber = aliceParity == Parity.odd ? 3 : 4;
      notifier.submitChoice(playerId: 'p2', choice: bobTossNumber);
      state = notifier.state;

      expect(state.match.phase, MatchPhase.roleSelection);
      expect(state.match.tossWinnerId, 'p1'); // Alice won toss

      // 5. Alice selects BAT
      notifier.selectCricketRole(CricketRole.bat);
      state = notifier.state;
      expect(state.match.phase, MatchPhase.firstInnings);
      expect(state.match.currentBatterId, 'p1');
      expect(state.match.currentBowlerId, 'p2');

      // 6. First ball: Alice picks 6
      notifier.submitChoice(playerId: 'p1', choice: 6);
      state = notifier.state;
      expect(state.waitingForHandoff, isTrue); // Pass to bowler (Bob)

      notifier.acknowledgeHandoff();
      // Bob picks 2 -> Different -> 6 runs scored!
      notifier.submitChoice(playerId: 'p2', choice: 2);
      state = notifier.state;
      expect(state.showBallOutcomeOverlay, isTrue);
      expect(state.match.currentInningsRuns, 6);
      expect(state.match.lastBallEvent?.runsScored, 6);

      notifier.dismissBallOutcome();

      // 7. Second ball: Alice picks 5, Bob picks 5 -> WICKET!
      notifier.submitChoice(playerId: 'p1', choice: 5);
      notifier.acknowledgeHandoff();
      notifier.submitChoice(playerId: 'p2', choice: 5);
      state = notifier.state;

      expect(state.match.phase, MatchPhase.inningsBreak);
      expect(state.match.firstInningsRuns, 6);
      expect(state.match.targetRuns, 7); // Target = 6 + 1 = 7

      notifier.dismissBallOutcome();

      // 8. Start Second Innings (Bob bats, Alice bowls)
      notifier.startSecondInnings();
      state = notifier.state;
      expect(state.match.phase, MatchPhase.secondInnings);
      expect(state.match.currentBatterId, 'p2');
      expect(state.match.currentBowlerId, 'p1');

      // 9. Chase ball: Bob picks 7, Alice picks 3 -> Bob scores 7 >= target 7 -> Bob WINS!
      notifier.submitChoice(playerId: 'p2', choice: 7);
      notifier.acknowledgeHandoff();
      notifier.submitChoice(playerId: 'p1', choice: 3);
      state = notifier.state;

      expect(state.match.phase, MatchPhase.matchFinished);
      expect(state.match.winnerId, 'p2');
      expect(state.match.resultType, MatchResultType.chaserWon);
      expect(state.match.player2.seriesScore, 1);
      expect(fakeRepo.savedMatches.length, 1);

      // 10. Rematch
      notifier.requestRematch();
      state = notifier.state;
      expect(state.match.phase, MatchPhase.tossInput);
      expect(state.match.player2.seriesScore, 1); // Preserves series score
      expect(state.match.firstInningsRuns, 0);
    });
  });
}
