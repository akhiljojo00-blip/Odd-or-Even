import '../../data/ranked_realtime_manager.dart';
import 'online_player_rank.dart';
import 'ranked_ball_event.dart';
import 'ranked_match.dart';
import 'ranked_match_settlement.dart';

/// Immutable state snapshot for an active server-authoritative Online Ranked match.
class RankedGameplayState {
  final RankedMatch? match;
  final String? currentUserId;
  final OnlinePlayerRank? myRank;
  final OnlinePlayerRank? opponentRank;
  final Map<String, dynamic>? myProfile;
  final Map<String, dynamic>? opponentProfile;
  final List<RankedBallEvent> ballEvents;
  final RankedMatchSettlement? settlement;
  final bool isLoading;
  final bool isSubmitting;
  final bool isClaimingTimeout;
  final bool isSurrendering;
  final bool isStartingSecondInnings;
  final bool isSelectingRole;
  final int? stagedChoice;
  final bool hasSubmittedThisTurn;
  final String? errorMessage;
  final RealtimeSyncStatus realtimeStatus;
  final int remainingTurnSeconds;
  final bool isOpponentDisconnected;
  final int opponentGraceRemainingSeconds;
  final bool showBallOutcomeOverlay;
  final RankedBallEvent? latestBallEvent;
  final OnlinePlayerRank? initialRankSnapshot;

  const RankedGameplayState({
    this.match,
    this.currentUserId,
    this.myRank,
    this.opponentRank,
    this.myProfile,
    this.opponentProfile,
    this.ballEvents = const [],
    this.settlement,
    this.isLoading = true,
    this.isSubmitting = false,
    this.isClaimingTimeout = false,
    this.isSurrendering = false,
    this.isStartingSecondInnings = false,
    this.isSelectingRole = false,
    this.stagedChoice,
    this.hasSubmittedThisTurn = false,
    this.errorMessage,
    this.realtimeStatus = RealtimeSyncStatus.disconnected,
    this.remainingTurnSeconds = 20,
    this.isOpponentDisconnected = false,
    this.opponentGraceRemainingSeconds = 30,
    this.showBallOutcomeOverlay = false,
    this.latestBallEvent,
    this.initialRankSnapshot,
  });

  /// Factory for the initial uninitialized state.
  factory RankedGameplayState.initial() => const RankedGameplayState();

  RankedGameplayState copyWith({
    RankedMatch? match,
    String? currentUserId,
    OnlinePlayerRank? myRank,
    OnlinePlayerRank? opponentRank,
    Map<String, dynamic>? myProfile,
    Map<String, dynamic>? opponentProfile,
    List<RankedBallEvent>? ballEvents,
    RankedMatchSettlement? settlement,
    bool? isLoading,
    bool? isSubmitting,
    bool? isClaimingTimeout,
    bool? isSurrendering,
    bool? isStartingSecondInnings,
    bool? isSelectingRole,
    int? stagedChoice,
    bool? hasSubmittedThisTurn,
    String? errorMessage,
    RealtimeSyncStatus? realtimeStatus,
    int? remainingTurnSeconds,
    bool? isOpponentDisconnected,
    int? opponentGraceRemainingSeconds,
    bool? showBallOutcomeOverlay,
    RankedBallEvent? latestBallEvent,
    OnlinePlayerRank? initialRankSnapshot,
    bool clearErrorMessage = false,
    bool clearStagedChoice = false,
  }) {
    return RankedGameplayState(
      match: match ?? this.match,
      currentUserId: currentUserId ?? this.currentUserId,
      myRank: myRank ?? this.myRank,
      opponentRank: opponentRank ?? this.opponentRank,
      myProfile: myProfile ?? this.myProfile,
      opponentProfile: opponentProfile ?? this.opponentProfile,
      ballEvents: ballEvents ?? this.ballEvents,
      settlement: settlement ?? this.settlement,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isClaimingTimeout: isClaimingTimeout ?? this.isClaimingTimeout,
      isSurrendering: isSurrendering ?? this.isSurrendering,
      isStartingSecondInnings: isStartingSecondInnings ?? this.isStartingSecondInnings,
      isSelectingRole: isSelectingRole ?? this.isSelectingRole,
      stagedChoice: clearStagedChoice ? null : (stagedChoice ?? this.stagedChoice),
      hasSubmittedThisTurn: hasSubmittedThisTurn ?? this.hasSubmittedThisTurn,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      realtimeStatus: realtimeStatus ?? this.realtimeStatus,
      remainingTurnSeconds: remainingTurnSeconds ?? this.remainingTurnSeconds,
      isOpponentDisconnected: isOpponentDisconnected ?? this.isOpponentDisconnected,
      opponentGraceRemainingSeconds: opponentGraceRemainingSeconds ?? this.opponentGraceRemainingSeconds,
      showBallOutcomeOverlay: showBallOutcomeOverlay ?? this.showBallOutcomeOverlay,
      latestBallEvent: latestBallEvent ?? this.latestBallEvent,
      initialRankSnapshot: initialRankSnapshot ?? this.initialRankSnapshot,
    );
  }

  // =========================================================================
  // AUTHORITATIVE COMPUTED HELPERS
  // =========================================================================

  /// True if caller is verified as a participant in this match.
  bool get isParticipant =>
      currentUserId != null &&
      match != null &&
      match!.isParticipant(currentUserId!);

  /// True if caller is player 1 in the match row.
  bool get isCallerPlayer1 =>
      currentUserId != null && match != null && currentUserId == match!.player1Id;

  /// Opponent user ID.
  String? get opponentId =>
      currentUserId != null && match != null
          ? match!.opponentId(currentUserId!)
          : null;

  /// Assigned toss parity for caller.
  PlayerParity? get myParity =>
      currentUserId != null && match != null
          ? match!.myParity(currentUserId!)
          : null;

  /// Assigned toss parity for opponent.
  PlayerParity? get opponentParity =>
      currentUserId != null && match != null
          ? match!.opponentParity(currentUserId!)
          : null;

  /// Whether caller is the current batter.
  bool get isBatting =>
      currentUserId != null &&
      match != null &&
      match!.currentBatterId == currentUserId;

  /// Whether caller is the current bowler.
  bool get isBowling =>
      currentUserId != null &&
      match != null &&
      match!.currentBowlerId == currentUserId;

  /// Whether caller won the toss.
  bool get isTossWinner =>
      currentUserId != null &&
      match != null &&
      match!.tossWinnerId == currentUserId;

  /// Match is completed by win, loss, tie, forfeit, or abandonment.
  bool get isCompleted => match?.isCompleted ?? false;

  /// True if caller is the match winner.
  bool get isWinner =>
      currentUserId != null && match != null && match!.isWinner(currentUserId!);

  /// True if match resulted in a tie.
  bool get isTie => match?.isTie ?? false;

  /// True if match ended via forfeit or surrender.
  bool get isForfeit => match?.isForfeit ?? false;

  /// Display name for caller.
  String get myDisplayName =>
      (myProfile?['display_name'] as String?)?.isNotEmpty == true
          ? myProfile!['display_name'] as String
          : 'You';

  /// Display name for opponent.
  String get opponentDisplayName =>
      (opponentProfile?['display_name'] as String?)?.isNotEmpty == true
          ? opponentProfile!['display_name'] as String
          : 'Opponent';

  /// Avatar index for caller.
  int get myAvatarIndex =>
      (myProfile?['avatar_index'] as num?)?.toInt() ?? 0;

  /// Avatar index for opponent.
  int get opponentAvatarIndex =>
      (opponentProfile?['avatar_index'] as num?)?.toInt() ?? 1;

  /// Whether caller can submit a number choice (1..6) right now.
  bool get canSubmitChoice {
    if (isLoading || isSubmitting || hasSubmittedThisTurn || match == null) {
      return false;
    }
    if (match!.isCompleted) return false;

    switch (match!.phase) {
      case RankedMatchPhase.tossInput:
        return true;
      case RankedMatchPhase.firstInnings:
      case RankedMatchPhase.secondInnings:
        return isBatting || isBowling;
      case RankedMatchPhase.roleSelection:
      case RankedMatchPhase.inningsBreak:
      case RankedMatchPhase.matchFinished:
      case RankedMatchPhase.matchForfeited:
        return false;
    }
  }

  /// Whether caller is eligible to claim a timeout forfeit win.
  bool get canClaimTimeout {
    if (isCompleted || match == null || isClaimingTimeout) return false;

    // Condition 1: Opponent grace period expired
    if (isOpponentDisconnected && opponentGraceRemainingSeconds <= 0) {
      return true;
    }

    // Condition 2: Caller has submitted choice and turn deadline expired while waiting for opponent
    if (hasSubmittedThisTurn && remainingTurnSeconds <= 0) {
      return true;
    }

    return false;
  }
}
