/// Authoritative settlement results for a concluded Ranked match.
/// Synchronized with `public.ranked_match_settlements`.
class RankedMatchSettlement {
  final String matchId;
  final String? winnerId;
  final String? loserId;
  final bool isTie;
  final bool isForfeit;
  final bool isAbandoned;
  final int legalBallsBowled;
  final bool isEarlyForfeit;
  final bool isPairStarCapped;
  final int p1StarsDelta;
  final int p2StarsDelta;
  final int p1MmrDelta;
  final int p2MmrDelta;
  final int p1XpAwarded;
  final int p2XpAwarded;
  final DateTime? settledAt;

  const RankedMatchSettlement({
    required this.matchId,
    this.winnerId,
    this.loserId,
    this.isTie = false,
    this.isForfeit = false,
    this.isAbandoned = false,
    this.legalBallsBowled = 0,
    this.isEarlyForfeit = false,
    this.isPairStarCapped = false,
    this.p1StarsDelta = 0,
    this.p2StarsDelta = 0,
    this.p1MmrDelta = 0,
    this.p2MmrDelta = 0,
    this.p1XpAwarded = 0,
    this.p2XpAwarded = 0,
    this.settledAt,
  });

  /// Returns the star delta for the specified player.
  int starsDeltaFor(String userId, String player1Id) {
    return userId == player1Id ? p1StarsDelta : p2StarsDelta;
  }

  /// Returns the MMR delta for the specified player.
  int mmrDeltaFor(String userId, String player1Id) {
    return userId == player1Id ? p1MmrDelta : p2MmrDelta;
  }

  /// Returns the XP awarded for the specified player.
  int xpAwardedFor(String userId, String player1Id) {
    return userId == player1Id ? p1XpAwarded : p2XpAwarded;
  }

  factory RankedMatchSettlement.fromJson(Map<String, dynamic> json) {
    return RankedMatchSettlement(
      matchId: json['match_id'] as String? ?? '',
      winnerId: json['winner_id'] as String?,
      loserId: json['loser_id'] as String?,
      isTie: json['is_tie'] as bool? ?? false,
      isForfeit: json['is_forfeit'] as bool? ?? false,
      isAbandoned: json['is_abandoned'] as bool? ?? false,
      legalBallsBowled: (json['legal_balls_bowled'] as num?)?.toInt() ?? 0,
      isEarlyForfeit: json['is_early_forfeit'] as bool? ?? false,
      isPairStarCapped: json['is_pair_star_capped'] as bool? ?? false,
      p1StarsDelta: (json['p1_stars_delta'] as num?)?.toInt() ?? 0,
      p2StarsDelta: (json['p2_stars_delta'] as num?)?.toInt() ?? 0,
      p1MmrDelta: (json['p1_mmr_delta'] as num?)?.toInt() ?? 0,
      p2MmrDelta: (json['p2_mmr_delta'] as num?)?.toInt() ?? 0,
      p1XpAwarded: (json['p1_xp_awarded'] as num?)?.toInt() ?? 0,
      p2XpAwarded: (json['p2_xp_awarded'] as num?)?.toInt() ?? 0,
      settledAt: json['settled_at'] != null
          ? DateTime.tryParse(json['settled_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'match_id': matchId,
      'winner_id': winnerId,
      'loser_id': loserId,
      'is_tie': isTie,
      'is_forfeit': isForfeit,
      'is_abandoned': isAbandoned,
      'legal_balls_bowled': legalBallsBowled,
      'is_early_forfeit': isEarlyForfeit,
      'is_pair_star_capped': isPairStarCapped,
      'p1_stars_delta': p1StarsDelta,
      'p2_stars_delta': p2StarsDelta,
      'p1_mmr_delta': p1MmrDelta,
      'p2_mmr_delta': p2MmrDelta,
      'p1_xp_awarded': p1XpAwarded,
      'p2_xp_awarded': p2XpAwarded,
      'settled_at': settledAt?.toIso8601String(),
    };
  }
}
