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
  final String? roomId;

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
    this.roomId,
  });

  PlayerInfo getPlayerById(String id) {
    if (player1.id == id) return player1;
    if (player2.id == id) return player2;
    return PlayerInfo(
      id: id,
      name: id.length >= 8 ? 'Player ${id.substring(0, 4)}' : (id.isNotEmpty ? id : 'Player'),
    );
  }

  PlayerInfo getOpponentOf(String id) {
    if (player1.id == id) return player2;
    if (player2.id == id) return player1;
    return player2;
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
    String? roomId,
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
      roomId: roomId ?? this.roomId,
    );
  }

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'phase': phase.name,
        'config': config.toJson(),
        'player1': player1.toJson(),
        'player2': player2.toJson(),
        'tossWinnerId': tossWinnerId,
        'battingFirstId': battingFirstId,
        'currentInningsNo': currentInningsNo,
        'firstInningsRuns': firstInningsRuns,
        'targetRuns': targetRuns,
        'currentBatterId': currentBatterId,
        'currentBowlerId': currentBowlerId,
        'currentInningsRuns': currentInningsRuns,
        'legalBallsBowled': legalBallsBowled,
        'ballHistory': ballHistory.map((e) => e.toJson()).toList(),
        'winnerId': winnerId,
        'resultType': resultType?.name,
        'seriesWinnerId': seriesWinnerId,
        'tossP1Choice': tossP1Choice,
        'tossP2Choice': tossP2Choice,
        'roomId': roomId,
      };

  factory GameMatchState.fromJson(Map<String, dynamic> json) {
    final parsedBallHistory = () {
      final raw = json['ballHistory'] as List<dynamic>?;
      if (raw == null) return const <BallEvent>[];
      final list = raw.map((e) => BallEvent.fromJson(e as Map<String, dynamic>)).toList();
      list.sort((a, b) {
        if (a.inningsNo != b.inningsNo) {
          return a.inningsNo.compareTo(b.inningsNo);
        }
        return a.ballNo.compareTo(b.ballNo);
      });
      return list;
    }();

    final parsedLastBall = json['lastBallEvent'] != null
        ? BallEvent.fromJson(json['lastBallEvent'] as Map<String, dynamic>)
        : (parsedBallHistory.isNotEmpty ? parsedBallHistory.last : null);

    return GameMatchState(
      matchId: json['matchId'] ?? json['id'] ?? '',
      phase: MatchPhase.fromValue((json['phase'] as String?) ?? 'toss_input'),
      config: json['config'] is Map<String, dynamic>
          ? MatchConfig.fromJson(json['config'] as Map<String, dynamic>)
          : const MatchConfig(),
      player1: json['player1'] is Map<String, dynamic>
          ? PlayerInfo.fromJson(json['player1'] as Map<String, dynamic>)
          : PlayerInfo(
              id: json['player1_id'] ?? 'p1',
              name: json['player1_name'] ?? 'Player 1',
              parity: json['player1_parity'] != null
                  ? (json['player1_parity'] == 'odd' ? Parity.odd : Parity.even)
                  : null,
              seriesScore: json['player1_series_score'] ?? 0,
              timeoutPoints: json['player1_timeout_points'] ?? 0,
            ),
      player2: json['player2'] is Map<String, dynamic>
          ? PlayerInfo.fromJson(json['player2'] as Map<String, dynamic>)
          : PlayerInfo(
              id: json['player2_id'] ?? 'p2',
              name: json['player2_name'] ?? 'Player 2',
              parity: json['player2_parity'] != null
                  ? (json['player2_parity'] == 'odd' ? Parity.odd : Parity.even)
                  : null,
              seriesScore: json['player2_series_score'] ?? 0,
              timeoutPoints: json['player2_timeout_points'] ?? 0,
            ),
      tossWinnerId: json['tossWinnerId'] ?? json['toss_winner_id'],
      battingFirstId: json['battingFirstId'] ?? json['batting_first_id'],
      currentInningsNo: json['currentInningsNo'] ?? json['current_innings_no'] ?? 1,
      firstInningsRuns: json['firstInningsRuns'] ?? json['first_innings_runs'] ?? 0,
      targetRuns: json['targetRuns'] ?? json['target_runs'],
      currentBatterId: json['currentBatterId'] ?? json['current_batter_id'],
      currentBowlerId: json['currentBowlerId'] ?? json['current_bowler_id'],
      currentInningsRuns: json['currentInningsRuns'] ?? json['current_innings_runs'] ?? 0,
      legalBallsBowled: json['legalBallsBowled'] ?? json['legal_balls_bowled'] ?? 0,
      ballHistory: parsedBallHistory,
      lastBallEvent: parsedLastBall,
      winnerId: json['winnerId'] ?? json['winner_id'],
      resultType: MatchResultType.fromValue(json['resultType'] ?? json['result_type']),
      seriesWinnerId: json['seriesWinnerId'] ?? json['series_winner_id'],
      tossP1Choice: json['tossP1Choice'] ?? json['toss_p1_choice'],
      tossP2Choice: json['tossP2Choice'] ?? json['toss_p2_choice'],
      roomId: json['roomId'] ?? json['room_id'],
    );
  }
}
