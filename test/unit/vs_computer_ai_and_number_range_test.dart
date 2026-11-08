import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/game/domain/ai/computer_player_strategy.dart';
import 'package:odd_or_even/features/game/domain/engine/odd_or_even_engine.dart';
import 'package:odd_or_even/features/game/domain/models/ball_event.dart';
import 'package:odd_or_even/features/game/domain/models/game_enums.dart';
import 'package:odd_or_even/features/game/domain/models/match_config.dart';
import 'package:odd_or_even/features/game/domain/models/player_info.dart';
import 'package:odd_or_even/features/history/data/match_history_repository.dart';
import 'package:odd_or_even/features/vs_computer/presentation/controllers/vs_computer_game_controller.dart';

class FakeMatchHistoryRepository extends MatchHistoryRepository {
  final List<dynamic> savedMatches = [];

  @override
  Future<void> saveMatchRecord(dynamic match) async {
    savedMatches.add(match);
  }
}

void main() {
  group('Configurable Number Range & MatchConfig Compatibility Tests', () {
    test('New MatchConfig instance defaults to maxChoice = 6', () {
      const config = MatchConfig();
      expect(config.maxChoice, equals(6));
    });

    test('Legacy serialized MatchConfig JSON without maxChoice defaults to 10', () {
      final legacyJson = {
        'gameMode': 'standard',
        'overs': 2,
        'decisionTimerSeconds': 10,
        'autoModeEnabled': false,
        'seriesTargetPoints': 6,
      };

      final parsed = MatchConfig.fromJson(legacyJson);
      expect(parsed.maxChoice, equals(10),
          reason: 'Legacy JSON without maxChoice must deserialize to 10 for backwards compatibility');
    });

    test('MatchConfig with explicit maxChoice = 6 deserializes to 6', () {
      final json6 = {
        'gameMode': 'standard',
        'overs': null,
        'decisionTimerSeconds': 10,
        'autoModeEnabled': false,
        'seriesTargetPoints': 6,
        'maxChoice': 6,
      };

      final parsed = MatchConfig.fromJson(json6);
      expect(parsed.maxChoice, equals(6));
    });

    test('MatchConfig serialization includes maxChoice', () {
      const config = MatchConfig(maxChoice: 6);
      final json = config.toJson();
      expect(json['maxChoice'], equals(6));
    });

    test('OddOrEvenEngine.isValidChoice respects dynamic bounds', () {
      // 1-6 range
      expect(OddOrEvenEngine.isValidChoice(1, maxChoice: 6), isTrue);
      expect(OddOrEvenEngine.isValidChoice(6, maxChoice: 6), isTrue);
      expect(OddOrEvenEngine.isValidChoice(7, maxChoice: 6), isFalse);
      expect(OddOrEvenEngine.isValidChoice(10, maxChoice: 6), isFalse);
      expect(OddOrEvenEngine.isValidChoice(0, maxChoice: 6), isFalse);
      expect(OddOrEvenEngine.isValidChoice(-1, maxChoice: 6), isFalse);

      // 1-10 range
      expect(OddOrEvenEngine.isValidChoice(1, maxChoice: 10), isTrue);
      expect(OddOrEvenEngine.isValidChoice(6, maxChoice: 10), isTrue);
      expect(OddOrEvenEngine.isValidChoice(10, maxChoice: 10), isTrue);
      expect(OddOrEvenEngine.isValidChoice(11, maxChoice: 10), isFalse);
      expect(OddOrEvenEngine.isValidChoice(0, maxChoice: 10), isFalse);
    });

    test('OddOrEvenEngine.resolveBall enforces maxChoice = 6 and rejects 7-10', () {
      const p1 = PlayerInfo(id: 'p1', name: 'Alice', parity: Parity.odd);
      const p2 = PlayerInfo(id: 'p2', name: 'Bob', parity: Parity.even);
      const config6 = MatchConfig(maxChoice: 6);

      var state = OddOrEvenEngine.initializeMatch(
        config: config6,
        player1: p1,
        player2: p2,
      );
      state = state.copyWith(
        phase: MatchPhase.firstInnings,
        currentBatterId: 'p1',
        currentBowlerId: 'p2',
        currentInningsNo: 1,
      );

      // Choices 1-6 succeed
      final validBall = OddOrEvenEngine.resolveBall(
        state: state,
        batterChoice: 6,
        bowlerChoice: 2,
      );
      expect(validBall.currentInningsRuns, equals(6));

      // Choice 7 throws ArgumentError
      expect(
        () => OddOrEvenEngine.resolveBall(
          state: state,
          batterChoice: 7,
          bowlerChoice: 2,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Bowler choice 8 throws ArgumentError
      expect(
        () => OddOrEvenEngine.resolveBall(
          state: state,
          batterChoice: 5,
          bowlerChoice: 8,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ComputerPlayerStrategy AI Tests', () {
    test('Easy AI always returns valid choices within range across 1,000 iterations', () {
      final rng = Random(42);
      for (int i = 0; i < 1000; i++) {
        // Range 6
        final tossChoice6 = ComputerPlayerStrategy.generateTossChoice(
          maxChoice: 6,
          difficulty: AiDifficulty.easy,
          random: rng,
        );
        expect(tossChoice6, inInclusiveRange(1, 6));

        final ballChoice6 = ComputerPlayerStrategy.generateBallChoice(
          difficulty: AiDifficulty.easy,
          aiRole: CricketRole.bat,
          maxChoice: 6,
          currentInningsNo: 1,
          currentInningsRuns: 0,
          targetRuns: null,
          ballHistory: const [],
          humanPlayerId: 'human',
          random: rng,
        );
        expect(ballChoice6, inInclusiveRange(1, 6));

        // Range 10
        final ballChoice10 = ComputerPlayerStrategy.generateBallChoice(
          difficulty: AiDifficulty.easy,
          aiRole: CricketRole.bowl,
          maxChoice: 10,
          currentInningsNo: 1,
          currentInningsRuns: 0,
          targetRuns: null,
          ballHistory: const [],
          humanPlayerId: 'human',
          random: rng,
        );
        expect(ballChoice10, inInclusiveRange(1, 10));
      }
    });

    test('Medium AI always returns valid choices within range across 1,000 iterations', () {
      final rng = Random(123);
      final fakeHistory = [
        const BallEvent(
          inningsNo: 1,
          ballNo: 1,
          batterId: 'human',
          bowlerId: 'computer',
          batterNumber: 4,
          bowlerNumber: 2,
          runsScored: 4,
          isWicket: false,
          cumulativeRuns: 4,
        ),
      ];

      for (int i = 0; i < 1000; i++) {
        final choice = ComputerPlayerStrategy.generateBallChoice(
          difficulty: AiDifficulty.medium,
          aiRole: i % 2 == 0 ? CricketRole.bat : CricketRole.bowl,
          maxChoice: 6,
          currentInningsNo: 2,
          currentInningsRuns: 10,
          targetRuns: 14,
          ballHistory: fakeHistory,
          humanPlayerId: 'human',
          random: rng,
        );
        expect(choice, inInclusiveRange(1, 6));
      }
    });

    test('Hard AI always returns valid choices within range across 1,000 iterations', () {
      final rng = Random(999);
      final fakeHistory = [
        const BallEvent(
          inningsNo: 1,
          ballNo: 1,
          batterId: 'human',
          bowlerId: 'computer',
          batterNumber: 5,
          bowlerNumber: 3,
          runsScored: 5,
          isWicket: false,
          cumulativeRuns: 5,
        ),
        const BallEvent(
          inningsNo: 1,
          ballNo: 2,
          batterId: 'human',
          bowlerId: 'computer',
          batterNumber: 5,
          bowlerNumber: 1,
          runsScored: 5,
          isWicket: false,
          cumulativeRuns: 10,
        ),
      ];

      for (int i = 0; i < 1000; i++) {
        final choice = ComputerPlayerStrategy.generateBallChoice(
          difficulty: AiDifficulty.hard,
          aiRole: i % 2 == 0 ? CricketRole.bat : CricketRole.bowl,
          maxChoice: 6,
          currentInningsNo: 2,
          currentInningsRuns: 8,
          targetRuns: 12,
          ballHistory: fakeHistory,
          humanPlayerId: 'human',
          random: rng,
        );
        expect(choice, inInclusiveRange(1, 6));
      }
    });

    test('Role selection returns valid CricketRole for all difficulty tiers', () {
      final rng = Random(77);
      for (final diff in AiDifficulty.values) {
        final role = ComputerPlayerStrategy.selectCricketRole(difficulty: diff, random: rng);
        expect(role, isIn([CricketRole.bat, CricketRole.bowl]));
      }
    });

    test('AI strategy has no parameter for pending human choice (Information Isolation)', () {
      // Architectural guarantee: ComputerPlayerStrategy.generateBallChoice accepts only public state
      final choice = ComputerPlayerStrategy.generateBallChoice(
        difficulty: AiDifficulty.hard,
        aiRole: CricketRole.bowl,
        maxChoice: 6,
        currentInningsNo: 1,
        currentInningsRuns: 0,
        targetRuns: null,
        ballHistory: const [],
        humanPlayerId: 'human',
      );
      expect(choice, inInclusiveRange(1, 6));
    });
  });

  group('VsComputerGameNotifier Full Match Flow Tests', () {
    late FakeMatchHistoryRepository fakeRepo;
    late VsComputerGameNotifier notifier;

    setUp(() {
      fakeRepo = FakeMatchHistoryRepository();
      notifier = VsComputerGameNotifier(fakeRepo);
    });

    test('Full match against AI completes from toss to match finished and saves history', () {
      notifier.startNewGame(
        config: const MatchConfig(overs: null, seriesTargetPoints: 1, maxChoice: 6),
        difficulty: AiDifficulty.easy,
        humanName: 'Champion',
      );

      var state = notifier.state;
      expect(state.match.phase, MatchPhase.tossInput);
      expect(state.match.config.maxChoice, equals(6));

      // 1. Submit toss
      notifier.submitTossChoice(4);
      state = notifier.state;

      // If human won toss, choose role; if computer won, AI picked automatically
      if (state.match.phase == MatchPhase.roleSelection) {
        notifier.selectCricketRole(CricketRole.bat);
        state = notifier.state;
      }

      expect(state.match.phase, MatchPhase.firstInnings);

      // 2. Play balls until first innings finishes (either wicket or limit)
      int safetyLimit = 0;
      while (state.match.phase == MatchPhase.firstInnings && safetyLimit < 50) {
        safetyLimit++;
        notifier.submitBallChoice(3);
        state = notifier.state;
        notifier.dismissBallOutcome();
        state = notifier.state;
      }

      expect(state.match.phase, MatchPhase.inningsBreak);
      expect(state.match.targetRuns, isNotNull);

      // 3. Start 2nd innings
      notifier.startSecondInnings();
      state = notifier.state;
      expect(state.match.phase, MatchPhase.secondInnings);

      // 4. Play 2nd innings until match completes
      safetyLimit = 0;
      while (state.match.phase == MatchPhase.secondInnings && safetyLimit < 50) {
        safetyLimit++;
        notifier.submitBallChoice(2);
        state = notifier.state;
        notifier.dismissBallOutcome();
        state = notifier.state;
      }

      expect(
        state.match.phase,
        isIn([MatchPhase.matchFinished, MatchPhase.seriesFinished]),
      );
      expect(fakeRepo.savedMatches.isNotEmpty, isTrue,
          reason: 'Match record must be saved in MatchHistoryRepository on finish');

      // 5. Rematch
      notifier.requestRematch();
      state = notifier.state;
      expect(state.match.phase, isIn([MatchPhase.tossInput, MatchPhase.firstInnings]));
    });

    test('Random auto-number respects match maxChoice', () {
      notifier.startNewGame(
        config: const MatchConfig(maxChoice: 6),
        difficulty: AiDifficulty.easy,
        humanName: 'Test',
      );

      for (int i = 0; i < 200; i++) {
        final autoNum = notifier.generateAutoNumber();
        expect(autoNum, inInclusiveRange(1, 6));
      }
    });
  });
}
