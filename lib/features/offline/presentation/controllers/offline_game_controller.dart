import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../game/domain/engine/odd_or_even_engine.dart';
import '../../../game/domain/models/game_enums.dart';
import '../../../game/domain/models/game_match_state.dart';
import '../../../game/domain/models/match_config.dart';
import '../../../game/domain/models/player_info.dart';
import '../../../history/data/match_history_repository.dart';

class OfflineGameState {
  final GameMatchState match;
  final int? p1PendingChoice;
  final int? p2PendingChoice;
  final bool waitingForHandoff;
  final String activeHandoffTargetPlayer;
  final bool showBallOutcomeOverlay;

  const OfflineGameState({
    required this.match,
    this.p1PendingChoice,
    this.p2PendingChoice,
    this.waitingForHandoff = false,
    this.activeHandoffTargetPlayer = '',
    this.showBallOutcomeOverlay = false,
  });

  OfflineGameState copyWith({
    GameMatchState? match,
    int? p1PendingChoice,
    int? p2PendingChoice,
    bool clearPendingChoices = false,
    bool? waitingForHandoff,
    String? activeHandoffTargetPlayer,
    bool? showBallOutcomeOverlay,
  }) {
    return OfflineGameState(
      match: match ?? this.match,
      p1PendingChoice: clearPendingChoices ? null : (p1PendingChoice ?? this.p1PendingChoice),
      p2PendingChoice: clearPendingChoices ? null : (p2PendingChoice ?? this.p2PendingChoice),
      waitingForHandoff: waitingForHandoff ?? this.waitingForHandoff,
      activeHandoffTargetPlayer: activeHandoffTargetPlayer ?? this.activeHandoffTargetPlayer,
      showBallOutcomeOverlay: showBallOutcomeOverlay ?? this.showBallOutcomeOverlay,
    );
  }
}

class OfflineGameNotifier extends StateNotifier<OfflineGameState> {
  final MatchHistoryRepository _historyRepo;

  OfflineGameNotifier(this._historyRepo)
      : super(
          OfflineGameState(
            match: OddOrEvenEngine.initializeMatch(
              config: const MatchConfig(),
              player1: const PlayerInfo(id: 'p1', name: 'Player 1'),
              player2: const PlayerInfo(id: 'p2', name: 'Player 2'),
            ),
          ),
        );

  /// Initializes a new match with custom config and player names.
  void startNewGame({
    required MatchConfig config,
    required String player1Name,
    required String player2Name,
  }) {
    final p1 = PlayerInfo(id: 'p1', name: player1Name.trim().isEmpty ? 'Player 1' : player1Name);
    final p2 = PlayerInfo(id: 'p2', name: player2Name.trim().isEmpty ? 'Player 2' : player2Name);

    final initialMatch = OddOrEvenEngine.initializeMatch(
      config: config,
      player1: p1,
      player2: p2,
    );

    state = OfflineGameState(match: initialMatch);
  }

  /// Submits number for the active player during pass-and-play.
  void submitChoice({
    required String playerId,
    required int choice,
  }) {
    if (state.match.phase == MatchPhase.tossInput) {
      _handleTossSubmission(playerId, choice);
    } else if (state.match.phase.isInningsActive) {
      _handleBallSubmission(playerId, choice);
    }
  }

  void _handleTossSubmission(String playerId, int choice) {
    if (playerId == 'p1') {
      // Player 1 submitted toss number. Prompt handoff to Player 2!
      state = state.copyWith(
        p1PendingChoice: choice,
        waitingForHandoff: true,
        activeHandoffTargetPlayer: state.match.player2.name,
      );
    } else {
      // Player 2 submitted toss number. Both are in! Resolve toss.
      final p1Choice = state.p1PendingChoice ?? 5;
      final resolvedTossState = OddOrEvenEngine.resolveToss(
        state: state.match,
        player1Choice: p1Choice,
        player2Choice: choice,
      );

      state = state.copyWith(
        match: resolvedTossState,
        clearPendingChoices: true,
        waitingForHandoff: false,
      );
    }
  }

  void _handleBallSubmission(String playerId, int choice) {
    final batterId = state.match.currentBatterId!;
    final isBatter = playerId == batterId;

    if (isBatter) {
      // Batter submits first. Handoff to bowler.
      state = state.copyWith(
        p1PendingChoice: choice,
        waitingForHandoff: true,
        activeHandoffTargetPlayer: state.match.currentBowler!.name,
      );
    } else {
      // Bowler submits second. Both numbers in! Resolve ball.
      final batterChoice = state.p1PendingChoice ?? 1;
      final bowlerChoice = choice;

      final updatedMatch = OddOrEvenEngine.resolveBall(
        state: state.match,
        batterChoice: batterChoice,
        bowlerChoice: bowlerChoice,
      );

      state = state.copyWith(
        match: updatedMatch,
        clearPendingChoices: true,
        waitingForHandoff: false,
        showBallOutcomeOverlay: true,
      );

      // Persist to history if match or series has completed
      if (updatedMatch.phase == MatchPhase.matchFinished ||
          updatedMatch.phase == MatchPhase.seriesFinished) {
        _historyRepo.saveMatchRecord(updatedMatch);
      }
    }
  }

  /// Toss winner selects Bat or Bowl.
  void selectCricketRole(CricketRole role) {
    final updatedMatch = OddOrEvenEngine.selectRole(
      state: state.match,
      choosingPlayerId: state.match.tossWinnerId!,
      chosenRole: role,
    );

    state = state.copyWith(match: updatedMatch);
  }

  /// Confirms handoff screen and opens turn for the target player.
  void acknowledgeHandoff() {
    state = state.copyWith(waitingForHandoff: false);
  }

  /// Dismisses ball outcome dialog.
  void dismissBallOutcome() {
    state = state.copyWith(showBallOutcomeOverlay: false);
  }

  /// Advances from innings break to second innings.
  void startSecondInnings() {
    final updatedMatch = OddOrEvenEngine.startSecondInnings(state.match);
    state = state.copyWith(match: updatedMatch);
  }

  /// Handles timeout when player fails to pick in time.
  void handleTimeout(String timedOutPlayerId) {
    final updatedMatch = OddOrEvenEngine.handleTimeout(
      state: state.match,
      timedOutPlayerId: timedOutPlayerId,
    );
    state = state.copyWith(match: updatedMatch);
  }

  /// Automatically picks a random valid number for auto mode.
  int generateAutoNumber() {
    return Random().nextInt(state.match.config.maxChoice) + 1;
  }

  /// Starts a fresh rematch match keeping series points.
  void requestRematch() {
    final rematch = OddOrEvenEngine.initializeRematch(previousState: state.match);
    state = OfflineGameState(match: rematch);
  }
}

final offlineGameProvider =
    StateNotifierProvider<OfflineGameNotifier, OfflineGameState>((ref) {
  final historyRepo = ref.watch(matchHistoryRepositoryProvider);
  return OfflineGameNotifier(historyRepo);
});
