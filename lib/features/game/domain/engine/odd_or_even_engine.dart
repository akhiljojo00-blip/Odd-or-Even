import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/ball_event.dart';
import '../models/game_enums.dart';
import '../models/game_match_state.dart';
import '../models/match_config.dart';
import '../models/player_info.dart';

class OddOrEvenEngine {
  static const int minChoice = 1;
  static const int maxChoice = 10;
  static final Random _defaultRandom = Random();
  static const Uuid _uuid = Uuid();

  /// Validates whether a number choice is legally in range 1..maxChoice.
  static bool isValidChoice(int choice, {int maxChoice = OddOrEvenEngine.maxChoice}) {
    return choice >= minChoice && choice <= maxChoice;
  }

  /// Initializes a brand new match with random parity assignment.
  static GameMatchState initializeMatch({
    required MatchConfig config,
    required PlayerInfo player1,
    required PlayerInfo player2,
    Random? random,
  }) {
    final rng = random ?? _defaultRandom;
    final p1IsOdd = rng.nextBool();
    final p1Parity = p1IsOdd ? Parity.odd : Parity.even;
    final p2Parity = p1Parity.opposite;

    final updatedP1 = player1.copyWith(parity: p1Parity);
    final updatedP2 = player2.copyWith(parity: p2Parity);

    return GameMatchState(
      matchId: _uuid.v4(),
      phase: MatchPhase.tossInput,
      config: config,
      player1: updatedP1,
      player2: updatedP2,
    );
  }

  /// Resolves the simultaneous toss submissions.
  static GameMatchState resolveToss({
    required GameMatchState state,
    required int player1Choice,
    required int player2Choice,
  }) {
    final max = state.config.maxChoice;
    if (!isValidChoice(player1Choice, maxChoice: max) || !isValidChoice(player2Choice, maxChoice: max)) {
      throw ArgumentError('Toss choices must be between $minChoice and $max');
    }

    final sum = player1Choice + player2Choice;
    final sumIsOdd = sum % 2 != 0;

    String winnerId;
    if (sumIsOdd) {
      winnerId = state.player1.parity == Parity.odd
          ? state.player1.id
          : state.player2.id;
    } else {
      winnerId = state.player1.parity == Parity.even
          ? state.player1.id
          : state.player2.id;
    }

    return state.copyWith(
      phase: MatchPhase.roleSelection,
      tossWinnerId: winnerId,
      tossP1Choice: player1Choice,
      tossP2Choice: player2Choice,
    );
  }

  /// Toss winner chooses Batting or Bowling.
  static GameMatchState selectRole({
    required GameMatchState state,
    required String choosingPlayerId,
    required CricketRole chosenRole,
  }) {
    if (state.tossWinnerId != choosingPlayerId) {
      throw StateError('Only toss winner can select Bat or Bowl role');
    }

    final opponent = state.getOpponentOf(choosingPlayerId);

    final String batterId;
    final String bowlerId;

    if (chosenRole == CricketRole.bat) {
      batterId = choosingPlayerId;
      bowlerId = opponent.id;
    } else {
      batterId = opponent.id;
      bowlerId = choosingPlayerId;
    }

    return state.copyWith(
      phase: MatchPhase.firstInnings,
      battingFirstId: batterId,
      currentBatterId: batterId,
      currentBowlerId: bowlerId,
      currentInningsNo: 1,
      currentInningsRuns: 0,
      legalBallsBowled: 0,
    );
  }

  /// Resolves one simultaneous ball selection.
  static GameMatchState resolveBall({
    required GameMatchState state,
    required int batterChoice,
    required int bowlerChoice,
  }) {
    final max = state.config.maxChoice;
    if (!isValidChoice(batterChoice, maxChoice: max) || !isValidChoice(bowlerChoice, maxChoice: max)) {
      throw ArgumentError('Ball numbers must be between $minChoice and $max');
    }
    if (!state.phase.isInningsActive) {
      throw StateError('Cannot resolve ball outside of active innings phase');
    }

    final isWicket = batterChoice == bowlerChoice;
    final runsScored = isWicket ? 0 : batterChoice;
    final newInningsRuns = state.currentInningsRuns + runsScored;
    final ballNo = state.legalBallsBowled + 1;

    final ballEvent = BallEvent(
      inningsNo: state.currentInningsNo,
      ballNo: ballNo,
      batterId: state.currentBatterId!,
      bowlerId: state.currentBowlerId!,
      batterNumber: batterChoice,
      bowlerNumber: bowlerChoice,
      runsScored: runsScored,
      isWicket: isWicket,
      cumulativeRuns: newInningsRuns,
    );

    final updatedHistory = List<BallEvent>.from(state.ballHistory)..add(ballEvent);

    // ---------------- INNINGS 1 ----------------
    if (state.currentInningsNo == 1) {
      final reachedBallLimit = state.config.maxBalls != null &&
          ballNo >= state.config.maxBalls!;

      if (isWicket || reachedBallLimit) {
        // First innings completes! Target is score + 1
        final target = newInningsRuns + 1;
        return state.copyWith(
          phase: MatchPhase.inningsBreak,
          firstInningsRuns: newInningsRuns,
          targetRuns: target,
          currentInningsRuns: newInningsRuns,
          legalBallsBowled: ballNo,
          ballHistory: updatedHistory,
          lastBallEvent: ballEvent,
        );
      } else {
        return state.copyWith(
          currentInningsRuns: newInningsRuns,
          legalBallsBowled: ballNo,
          ballHistory: updatedHistory,
          lastBallEvent: ballEvent,
        );
      }
    }

    // ---------------- INNINGS 2 (CHASE) ----------------
    else {
      final target = state.targetRuns!;
      final reachedBallLimit = state.config.maxBalls != null &&
          ballNo >= state.config.maxBalls!;

      // 1. Chaser reaches or passes target -> Chaser Wins immediately
      if (newInningsRuns >= target) {
        final winnerId = state.currentBatterId!;
        return _finalizeMatch(
          state: state.copyWith(
            currentInningsRuns: newInningsRuns,
            legalBallsBowled: ballNo,
            ballHistory: updatedHistory,
            lastBallEvent: ballEvent,
          ),
          winnerId: winnerId,
          resultType: MatchResultType.chaserWon,
        );
      }

      // 2. Chasing batter dismissed or over limit reached
      if (isWicket || reachedBallLimit) {
        if (newInningsRuns == state.firstInningsRuns) {
          // Exactly tied!
          return _finalizeMatch(
            state: state.copyWith(
              currentInningsRuns: newInningsRuns,
              legalBallsBowled: ballNo,
              ballHistory: updatedHistory,
              lastBallEvent: ballEvent,
            ),
            winnerId: null,
            resultType: MatchResultType.tie,
          );
        } else {
          // Defending bowler wins!
          final winnerId = state.currentBowlerId!;
          return _finalizeMatch(
            state: state.copyWith(
              currentInningsRuns: newInningsRuns,
              legalBallsBowled: ballNo,
              ballHistory: updatedHistory,
              lastBallEvent: ballEvent,
            ),
            winnerId: winnerId,
            resultType: MatchResultType.defenderWon,
          );
        }
      }

      // 3. Normal ball in chase continues
      return state.copyWith(
        currentInningsRuns: newInningsRuns,
        legalBallsBowled: ballNo,
        ballHistory: updatedHistory,
        lastBallEvent: ballEvent,
      );
    }
  }

  /// Begins Second Innings after Innings Break.
  static GameMatchState startSecondInnings(GameMatchState state) {
    if (state.phase != MatchPhase.inningsBreak) {
      throw StateError('Can only start second innings from inningsBreak phase');
    }

    // Swap roles: previous bowler becomes batter, previous batter becomes bowler
    final newBatterId = state.currentBowlerId!;
    final newBowlerId = state.currentBatterId!;

    return state.copyWith(
      phase: MatchPhase.secondInnings,
      currentInningsNo: 2,
      currentBatterId: newBatterId,
      currentBowlerId: newBowlerId,
      currentInningsRuns: 0,
      legalBallsBowled: 0,
      clearLastBall: true,
    );
  }

  /// Finalizes match, adds series points, checks if series target was hit.
  static GameMatchState _finalizeMatch({
    required GameMatchState state,
    required String? winnerId,
    required MatchResultType resultType,
  }) {
    PlayerInfo p1 = state.player1;
    PlayerInfo p2 = state.player2;
    String? seriesWinner;

    if (winnerId != null) {
      if (winnerId == p1.id) {
        final newScore = p1.seriesScore + 1;
        p1 = p1.copyWith(seriesScore: newScore);
        if (newScore >= state.config.seriesTargetPoints) {
          seriesWinner = p1.id;
        }
      } else if (winnerId == p2.id) {
        final newScore = p2.seriesScore + 1;
        p2 = p2.copyWith(seriesScore: newScore);
        if (newScore >= state.config.seriesTargetPoints) {
          seriesWinner = p2.id;
        }
      }
    }

    final newPhase = seriesWinner != null
        ? MatchPhase.seriesFinished
        : MatchPhase.matchFinished;

    return state.copyWith(
      phase: newPhase,
      winnerId: winnerId,
      resultType: resultType,
      player1: p1,
      player2: p2,
      seriesWinnerId: seriesWinner,
    );
  }

  /// Handles connected player timeout. Opponent receives 1 timeout point.
  static GameMatchState handleTimeout({
    required GameMatchState state,
    required String timedOutPlayerId,
  }) {
    if (timedOutPlayerId == state.player1.id) {
      final updatedP2 = state.player2.copyWith(
        timeoutPoints: state.player2.timeoutPoints + 1,
      );
      return state.copyWith(player2: updatedP2);
    } else if (timedOutPlayerId == state.player2.id) {
      final updatedP1 = state.player1.copyWith(
        timeoutPoints: state.player1.timeoutPoints + 1,
      );
      return state.copyWith(player1: updatedP1);
    }
    return state;
  }

  /// Handles player forfeit (e.g. disconnect grace expiration or abandonment).
  static GameMatchState forfeitMatch({
    required GameMatchState state,
    required String forfeitingPlayerId,
  }) {
    if (state.phase == MatchPhase.matchFinished ||
        state.phase == MatchPhase.seriesFinished ||
        state.phase == MatchPhase.matchForfeited) {
      return state;
    }

    final opponent = state.getOpponentOf(forfeitingPlayerId);
    return _finalizeMatch(
      state: state.copyWith(phase: MatchPhase.matchForfeited),
      winnerId: opponent.id,
      resultType: MatchResultType.forfeit,
    );
  }

  /// Prepares a fresh rematch match keeping cumulative series score.
  static GameMatchState initializeRematch({
    required GameMatchState previousState,
    Random? random,
  }) {
    final rng = random ?? _defaultRandom;
    final p1IsOdd = rng.nextBool();
    final p1Parity = p1IsOdd ? Parity.odd : Parity.even;
    final p2Parity = p1Parity.opposite;

    // Reset match-level timeout points while preserving seriesScore
    final updatedP1 = previousState.player1.copyWith(
      parity: p1Parity,
      timeoutPoints: 0,
    );
    final updatedP2 = previousState.player2.copyWith(
      parity: p2Parity,
      timeoutPoints: 0,
    );

    return GameMatchState(
      matchId: _uuid.v4(),
      phase: MatchPhase.tossInput,
      config: previousState.config,
      player1: updatedP1,
      player2: updatedP2,
    );
  }
}
