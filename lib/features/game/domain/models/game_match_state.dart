import 'ball_event.dart';
import 'game_enums.dart';
import 'match_config.dart';
import 'player_info.dart';

class GameMatchState {
  final String matchId;
  final MatchPhase phase;
  final MatchConfig config;
  final PlayerInfo player1;
  final PlayerInfo player2;
  final String? tossWinnerId;
  final String? battingFirstId;
  final int currentInningsNo;
  final int firstInningsRuns;
  final int? targetRuns;
  final String? currentBatterId;
  final String? currentBowlerId;
  final int currentInningsRuns;
  final int legalBallsBowled;
  final List<BallEvent> ballHistory;
  final String? winnerId;
  final MatchResultType? resultType;
  final String? seriesWinnerId;
  final BallEvent? lastBallEvent;
  final int? tossP1Choice;
  final int? tossP2Choice;

  const GameMatchState({
    required this.matchId,
    required this.phase,
    required this.config,
    required this.player1,
    required this.player2,
    this.tossWinnerId,
    this.battingFirstId,
    this.currentInningsNo = 1,
    this.firstInningsRuns = 0,
    this.targetRuns,
    this.currentBatterId,
    this.currentBowlerId,
    this.currentInningsRuns = 0,
    this.legalBallsBowled = 0,
    this.ballHistory = const [],
    this.winnerId,
    this.resultType,
    this.seriesWinnerId,
    this.lastBallEvent,
    this.tossP1Choice,
    this.tossP2Choice,
  });

  PlayerInfo getPlayerById(String id) {
    if (player1.id == id) return player1;
    if (player2.id == id) return player2;
    throw ArgumentError('Player ID not found in match: $id');
  }

  PlayerInfo getOpponentOf(String id) {
    if (player1.id == id) return player2;
    if (player2.id == id) return player1;
    throw ArgumentError('Player ID not found in match: $id');
  }

  PlayerInfo? get currentBatter =>
      currentBatterId != null ? getPlayerById(currentBatterId!) : null;

  PlayerInfo? get currentBowler =>
      currentBowlerId != null ? getPlayerById(currentBowlerId!) : null;

  PlayerInfo? get tossWinner =>
      tossWinnerId != null ? getPlayerById(tossWinnerId!) : null;

  PlayerInfo? get matchWinner =>
      winnerId != null ? getPlayerById(winnerId!) : null;

  PlayerInfo? get seriesWinner =>
      seriesWinnerId != null ? getPlayerById(seriesWinnerId!) : null;

  GameMatchState copyWith({
    String? matchId,
    MatchPhase? phase,
    MatchConfig? config,
    PlayerInfo? player1,
    PlayerInfo? player2,
    String? tossWinnerId,
    String? battingFirstId,
    int? currentInningsNo,
    int? firstInningsRuns,
    int? targetRuns,
    String? currentBatterId,
    String? currentBowlerId,
    int? currentInningsRuns,
    int? legalBallsBowled,
    List<BallEvent>? ballHistory,
    String? winnerId,
    MatchResultType? resultType,
    String? seriesWinnerId,
    BallEvent? lastBallEvent,
    int? tossP1Choice,
    int? tossP2Choice,
    bool clearWinner = false,
    bool clearLastBall = false,
    bool clearTossChoices = false,
  }) {
    return GameMatchState(
      matchId: matchId ?? this.matchId,
      phase: phase ?? this.phase,
      config: config ?? this.config,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      tossWinnerId: tossWinnerId ?? this.tossWinnerId,
      battingFirstId: battingFirstId ?? this.battingFirstId,
      currentInningsNo: currentInningsNo ?? this.currentInningsNo,
      firstInningsRuns: firstInningsRuns ?? this.firstInningsRuns,
      targetRuns: targetRuns ?? this.targetRuns,
      currentBatterId: currentBatterId ?? this.currentBatterId,
      currentBowlerId: currentBowlerId ?? this.currentBowlerId,
      currentInningsRuns: currentInningsRuns ?? this.currentInningsRuns,
      legalBallsBowled: legalBallsBowled ?? this.legalBallsBowled,
      ballHistory: ballHistory ?? this.ballHistory,
      winnerId: clearWinner ? null : (winnerId ?? this.winnerId),
      resultType: clearWinner ? null : (resultType ?? this.resultType),
      seriesWinnerId: seriesWinnerId ?? this.seriesWinnerId,
      lastBallEvent: clearLastBall ? null : (lastBallEvent ?? this.lastBallEvent),
      tossP1Choice: clearTossChoices ? null : (tossP1Choice ?? this.tossP1Choice),
      tossP2Choice: clearTossChoices ? null : (tossP2Choice ?? this.tossP2Choice),
    );
  }
}
