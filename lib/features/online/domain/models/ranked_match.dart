/// Lifecycle phases for a server-authoritative Ranked match.
enum RankedMatchPhase {
  tossInput('toss_input'),
  roleSelection('role_selection'),
  firstInnings('first_innings'),
  inningsBreak('innings_break'),
  secondInnings('second_innings'),
  matchFinished('match_finished'),
  matchForfeited('match_forfeited');

  final String dbValue;
  const RankedMatchPhase(this.dbValue);

  static RankedMatchPhase fromString(String value) {
    for (final phase in RankedMatchPhase.values) {
      if (phase.dbValue == value || phase.name == value) {
        return phase;
      }
    }
    return RankedMatchPhase.tossInput;
  }
}

/// Parity assigned to players during ranked matchmaking.
enum PlayerParity {
  odd('odd'),
  even('even');

  final String dbValue;
  const PlayerParity(this.dbValue);

  static PlayerParity fromString(String value) {
    return value.toLowerCase() == 'even' ? PlayerParity.even : PlayerParity.odd;
  }
}

/// Outcome result type for a completed ranked match.
enum RankedResultType {
  runs('runs'),
  wickets('wickets'),
  tie('tie'),
  forfeit('forfeit'),
  abandoned('abandoned');

  final String dbValue;
  const RankedResultType(this.dbValue);

  static RankedResultType? fromString(String? value) {
    if (value == null) return null;
    for (final type in RankedResultType.values) {
      if (type.dbValue == value || type.name == value) {
        return type;
      }
    }
    return null;
  }
}

/// Fixed match configuration for Online Ranked play.
class RankedMatchConfig {
  final int numberRange;
  final int overs;

  const RankedMatchConfig({
    this.numberRange = 6,
    this.overs = 2,
  });

  factory RankedMatchConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RankedMatchConfig();
    return RankedMatchConfig(
      numberRange: (json['number_range'] as num?)?.toInt() ?? 6,
      overs: (json['overs'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number_range': numberRange,
      'overs': overs,
    };
  }
}

/// Server-authoritative Ranked Match state snapshot.
/// Synchronized with `public.ranked_matches`.
class RankedMatch {
  final String id;
  final int? seasonId;
  final RankedMatchPhase phase;
  final int version;
  final RankedMatchConfig config;
  final String player1Id;
  final String player2Id;
  final PlayerParity player1Parity;
  final PlayerParity player2Parity;
  final String? tossWinnerId;
  final String? battingFirstId;
  final int currentInningsNo;
  final int firstInningsRuns;
  final int? targetRuns;
  final String? currentBatterId;
  final String? currentBowlerId;
  final int currentInningsRuns;
  final int legalBallsBowled;
  final String? winnerId;
  final RankedResultType? resultType;
  final DateTime? turnDeadlineAt;
  final DateTime? player1HeartbeatAt;
  final DateTime? player2HeartbeatAt;
  final DateTime? p1DisconnectedAt;
  final DateTime? p2DisconnectedAt;
  final DateTime? p1GraceExpiresAt;
  final DateTime? p2GraceExpiresAt;
  final int? p1SavedTurnSeconds;
  final int? p2SavedTurnSeconds;
  final int p1GraceRemainingSeconds;
  final int p2GraceRemainingSeconds;
  final int p1DisconnectCount;
  final int p2DisconnectCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RankedMatch({
    required this.id,
    this.seasonId,
    required this.phase,
    this.version = 1,
    this.config = const RankedMatchConfig(),
    required this.player1Id,
    required this.player2Id,
    required this.player1Parity,
    required this.player2Parity,
    this.tossWinnerId,
    this.battingFirstId,
    this.currentInningsNo = 1,
    this.firstInningsRuns = 0,
    this.targetRuns,
    this.currentBatterId,
    this.currentBowlerId,
    this.currentInningsRuns = 0,
    this.legalBallsBowled = 0,
    this.winnerId,
    this.resultType,
    this.turnDeadlineAt,
    this.player1HeartbeatAt,
    this.player2HeartbeatAt,
    this.p1DisconnectedAt,
    this.p2DisconnectedAt,
    this.p1GraceExpiresAt,
    this.p2GraceExpiresAt,
    this.p1SavedTurnSeconds,
    this.p2SavedTurnSeconds,
    this.p1GraceRemainingSeconds = 30,
    this.p2GraceRemainingSeconds = 30,
    this.p1DisconnectCount = 0,
    this.p2DisconnectCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// True if the match has concluded by win, loss, tie, forfeit, or abandonment.
  bool get isCompleted =>
      phase == RankedMatchPhase.matchFinished ||
      phase == RankedMatchPhase.matchForfeited;

  /// True if caller is a registered participant in this match.
  bool isParticipant(String userId) =>
      userId == player1Id || userId == player2Id;

  /// Returns the opponent's user ID for the given participant.
  String? opponentId(String myUserId) {
    if (myUserId == player1Id) return player2Id;
    if (myUserId == player2Id) return player1Id;
    return null;
  }

  /// Returns caller's assigned toss parity.
  PlayerParity? myParity(String myUserId) {
    if (myUserId == player1Id) return player1Parity;
    if (myUserId == player2Id) return player2Parity;
    return null;
  }

  /// Returns opponent's assigned toss parity.
  PlayerParity? opponentParity(String myUserId) {
    if (myUserId == player1Id) return player2Parity;
    if (myUserId == player2Id) return player1Parity;
    return null;
  }

  /// Returns whether caller is the match winner.
  bool isWinner(String myUserId) => winnerId == myUserId;

  /// Match concluded in a tie.
  bool get isTie => resultType == RankedResultType.tie;

  /// Match concluded via forfeit or concession.
  bool get isForfeit => resultType == RankedResultType.forfeit;

  /// Match concluded via simultaneous mutual abandonment.
  bool get isAbandoned => resultType == RankedResultType.abandoned;

  /// Checks if the opponent is currently disconnected and in a grace window.
  bool isOpponentDisconnected(String myUserId) {
    if (myUserId == player1Id) {
      return p2GraceExpiresAt != null && DateTime.now().isBefore(p2GraceExpiresAt!);
    } else if (myUserId == player2Id) {
      return p1GraceExpiresAt != null && DateTime.now().isBefore(p1GraceExpiresAt!);
    }
    return false;
  }

  /// Opponent grace expiration timestamp.
  DateTime? opponentGraceExpiresAt(String myUserId) {
    return myUserId == player1Id ? p2GraceExpiresAt : p1GraceExpiresAt;
  }

  /// Opponent remaining grace seconds.
  int opponentGraceRemaining(String myUserId) {
    return myUserId == player1Id
        ? p2GraceRemainingSeconds
        : p1GraceRemainingSeconds;
  }

  /// Whether it is caller's turn to take an action.
  bool isMyTurn(String myUserId) {
    if (isCompleted) return false;
    switch (phase) {
      case RankedMatchPhase.tossInput:
        return true;
      case RankedMatchPhase.roleSelection:
        return tossWinnerId == myUserId;
      case RankedMatchPhase.firstInnings:
      case RankedMatchPhase.secondInnings:
        return true;
      case RankedMatchPhase.inningsBreak:
        return true;
      case RankedMatchPhase.matchFinished:
      case RankedMatchPhase.matchForfeited:
        return false;
    }
  }

  factory RankedMatch.fromJson(Map<String, dynamic> json) {
    return RankedMatch(
      id: json['id'] as String? ?? '',
      seasonId: (json['season_id'] as num?)?.toInt(),
      phase: RankedMatchPhase.fromString(json['phase'] as String? ?? 'toss_input'),
      version: (json['version'] as num?)?.toInt() ?? 1,
      config: RankedMatchConfig.fromJson(
        json['config'] is Map<String, dynamic>
            ? json['config'] as Map<String, dynamic>
            : (json['config'] is Map ? Map<String, dynamic>.from(json['config'] as Map) : null),
      ),
      player1Id: json['player1_id'] as String? ?? '',
      player2Id: json['player2_id'] as String? ?? '',
      player1Parity: PlayerParity.fromString(json['player1_parity'] as String? ?? 'odd'),
      player2Parity: PlayerParity.fromString(json['player2_parity'] as String? ?? 'even'),
      tossWinnerId: json['toss_winner_id'] as String?,
      battingFirstId: json['batting_first_id'] as String?,
      currentInningsNo: (json['current_innings_no'] as num?)?.toInt() ?? 1,
      firstInningsRuns: (json['first_innings_runs'] as num?)?.toInt() ?? 0,
      targetRuns: (json['target_runs'] as num?)?.toInt(),
      currentBatterId: json['current_batter_id'] as String?,
      currentBowlerId: json['current_bowler_id'] as String?,
      currentInningsRuns: (json['current_innings_runs'] as num?)?.toInt() ?? 0,
      legalBallsBowled: (json['legal_balls_bowled'] as num?)?.toInt() ?? 0,
      winnerId: json['winner_id'] as String?,
      resultType: RankedResultType.fromString(json['result_type'] as String?),
      turnDeadlineAt: json['turn_deadline_at'] != null ? DateTime.tryParse(json['turn_deadline_at'].toString()) : null,
      player1HeartbeatAt: json['player1_heartbeat_at'] != null ? DateTime.tryParse(json['player1_heartbeat_at'].toString()) : null,
      player2HeartbeatAt: json['player2_heartbeat_at'] != null ? DateTime.tryParse(json['player2_heartbeat_at'].toString()) : null,
      p1DisconnectedAt: json['p1_disconnected_at'] != null ? DateTime.tryParse(json['p1_disconnected_at'].toString()) : null,
      p2DisconnectedAt: json['p2_disconnected_at'] != null ? DateTime.tryParse(json['p2_disconnected_at'].toString()) : null,
      p1GraceExpiresAt: json['p1_grace_expires_at'] != null ? DateTime.tryParse(json['p1_grace_expires_at'].toString()) : null,
      p2GraceExpiresAt: json['p2_grace_expires_at'] != null ? DateTime.tryParse(json['p2_grace_expires_at'].toString()) : null,
      p1SavedTurnSeconds: (json['p1_saved_turn_seconds'] as num?)?.toInt(),
      p2SavedTurnSeconds: (json['p2_saved_turn_seconds'] as num?)?.toInt(),
      p1GraceRemainingSeconds: (json['p1_grace_remaining_seconds'] as num?)?.toInt() ?? 30,
      p2GraceRemainingSeconds: (json['p2_grace_remaining_seconds'] as num?)?.toInt() ?? 30,
      p1DisconnectCount: (json['p1_disconnect_count'] as num?)?.toInt() ?? 0,
      p2DisconnectCount: (json['p2_disconnect_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'season_id': seasonId,
      'phase': phase.dbValue,
      'version': version,
      'config': config.toJson(),
      'player1_id': player1Id,
      'player2_id': player2Id,
      'player1_parity': player1Parity.dbValue,
      'player2_parity': player2Parity.dbValue,
      'toss_winner_id': tossWinnerId,
      'batting_first_id': battingFirstId,
      'current_innings_no': currentInningsNo,
      'first_innings_runs': firstInningsRuns,
      'target_runs': targetRuns,
      'current_batter_id': currentBatterId,
      'current_bowler_id': currentBowlerId,
      'current_innings_runs': currentInningsRuns,
      'legal_balls_bowled': legalBallsBowled,
      'winner_id': winnerId,
      'result_type': resultType?.dbValue,
      'turn_deadline_at': turnDeadlineAt?.toIso8601String(),
      'player1_heartbeat_at': player1HeartbeatAt?.toIso8601String(),
      'player2_heartbeat_at': player2HeartbeatAt?.toIso8601String(),
      'p1_disconnected_at': p1DisconnectedAt?.toIso8601String(),
      'p2_disconnected_at': p2DisconnectedAt?.toIso8601String(),
      'p1_grace_expires_at': p1GraceExpiresAt?.toIso8601String(),
      'p2_grace_expires_at': p2GraceExpiresAt?.toIso8601String(),
      'p1_saved_turn_seconds': p1SavedTurnSeconds,
      'p2_saved_turn_seconds': p2SavedTurnSeconds,
      'p1_grace_remaining_seconds': p1GraceRemainingSeconds,
      'p2_grace_remaining_seconds': p2GraceRemainingSeconds,
      'p1_disconnect_count': p1DisconnectCount,
      'p2_disconnect_count': p2DisconnectCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
