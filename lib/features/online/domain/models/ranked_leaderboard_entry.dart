import '../../../progression/domain/models/rank_tier.dart';

/// Public leaderboard projection model.
/// Synchronized with `public.v_ranked_leaderboard`.
class RankedLeaderboardEntry {
  final String userId;
  final String displayName;
  final int avatarIndex;
  final RankTier tier;
  final RankDivision? division;
  final int stars;
  final int mmr;
  final int winStreak;
  final int totalRankedWins;
  final int totalRankedMatches;
  final int leaderboardRank;

  const RankedLeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarIndex = 0,
    required this.tier,
    this.division,
    this.stars = 0,
    this.mmr = 1000,
    this.winStreak = 0,
    this.totalRankedWins = 0,
    this.totalRankedMatches = 0,
    this.leaderboardRank = 1,
  });

  /// Win percentage.
  double get winRate => totalRankedMatches > 0
      ? (totalRankedWins / totalRankedMatches) * 100.0
      : 0.0;

  /// Full rank label (e.g. "Gold II" or "Master").
  String get fullRankLabel {
    if (tier.hasDivisions && division != null) {
      return '${tier.displayName} ${division!.label}';
    }
    return tier.displayName;
  }

  factory RankedLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final rawTierStr = json['tier'] as String? ?? 'Bronze';
    final parsedTier = RankTier.fromString(rawTierStr);

    final rawDivStr = json['division'] as String?;
    final parsedDivision = (rawDivStr != null && parsedTier.hasDivisions)
        ? RankDivision.fromString(rawDivStr)
        : (parsedTier.hasDivisions ? RankDivision.III : null);

    return RankedLeaderboardEntry(
      userId: json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Anonymous Player',
      avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      tier: parsedTier,
      division: parsedDivision,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      mmr: (json['mmr'] as num?)?.toInt() ?? 1000,
      winStreak: (json['win_streak'] as num?)?.toInt() ?? 0,
      totalRankedWins: (json['total_ranked_wins'] as num?)?.toInt() ?? 0,
      totalRankedMatches: (json['total_ranked_matches'] as num?)?.toInt() ?? 0,
      leaderboardRank: (json['leaderboard_rank'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'avatar_index': avatarIndex,
      'tier': tier.displayName,
      'division': division?.label,
      'stars': stars,
      'mmr': mmr,
      'win_streak': winStreak,
      'total_ranked_wins': totalRankedWins,
      'total_ranked_matches': totalRankedMatches,
      'leaderboard_rank': leaderboardRank,
    };
  }
}
