import '../../../progression/domain/models/rank_tier.dart';
import '../../../progression/domain/models/xp_progress.dart';

/// Server-authoritative online ranked progression model for an authenticated player.
/// Synchronized with `public.online_player_ranks` in PostgreSQL.
class OnlinePlayerRank {
  final String userId;
  final int totalXp;
  final RankTier tier;
  final RankDivision? division;
  final int stars;
  final int mmr;
  final RankTier peakTier;
  final RankDivision? peakDivision;
  final int peakMmr;
  final int winStreak;
  final int longestWinStreak;
  final bool demotionShieldActive;
  final int totalRankedMatches;
  final int totalRankedWins;
  final int totalRankedLosses;
  final int totalRankedTies;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OnlinePlayerRank({
    required this.userId,
    this.totalXp = 0,
    required this.tier,
    this.division,
    this.stars = 0,
    this.mmr = 1000,
    required this.peakTier,
    this.peakDivision,
    this.peakMmr = 1000,
    this.winStreak = 0,
    this.longestWinStreak = 0,
    this.demotionShieldActive = false,
    this.totalRankedMatches = 0,
    this.totalRankedWins = 0,
    this.totalRankedLosses = 0,
    this.totalRankedTies = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor for a freshly provisioned player entry.
  factory OnlinePlayerRank.initial(String userId) {
    return OnlinePlayerRank(
      userId: userId,
      totalXp: 0,
      tier: RankTier.bronze,
      division: RankDivision.III,
      stars: 0,
      mmr: 1000,
      peakTier: RankTier.bronze,
      peakDivision: RankDivision.III,
      peakMmr: 1000,
      winStreak: 0,
      longestWinStreak: 0,
      demotionShieldActive: false,
      totalRankedMatches: 0,
      totalRankedWins: 0,
      totalRankedLosses: 0,
      totalRankedTies: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Calculates the canonical account XP progress using `XpEconomy.calculateProgress`.
  XpProgress get xpProgress => XpEconomy.calculateProgress(totalXp);

  /// Player level derived from cumulative server total XP.
  int get playerLevel => xpProgress.level;

  /// Win percentage rounded to 1 decimal place.
  double get winRate => totalRankedMatches > 0
      ? (totalRankedWins / totalRankedMatches) * 100.0
      : 0.0;

  /// Full rank label (e.g. "Bronze III", "Gold I", "Master", "Grand Master").
  String get fullRankLabel {
    if (tier.hasDivisions && division != null) {
      return '${tier.displayName} ${division!.label}';
    }
    return tier.displayName;
  }

  /// Peak rank label.
  String get peakRankLabel {
    if (peakTier.hasDivisions && peakDivision != null) {
      return '${peakTier.displayName} ${peakDivision!.label}';
    }
    return peakTier.displayName;
  }

  /// Whether player is in Master or Grand Master tier (no divisions).
  bool get isMasterOrGrandMaster =>
      tier == RankTier.master || tier == RankTier.grandMaster;

  /// Whether player is Grand Master.
  bool get isGrandMaster => tier == RankTier.grandMaster;

  /// Max stars for the current tier.
  int get maxStars => tier.maxStars;

  /// Loss floor protection (Bronze).
  bool get hasZeroStarLoss => tier.hasZeroStarLoss;

  /// Tier floor protection (Bronze, Silver, Gold).
  bool get isTierFloor => tier.isTierFloor;

  /// Demotion shield support (Platinum, Diamond, Elite, Pro Elite, Legend, Master).
  bool get hasDemotionShield => tier.hasDemotionShield;

  /// Win streak bonus support (Bronze, Silver, Gold).
  bool get hasStreakBonus => tier.hasStreakBonus;

  factory OnlinePlayerRank.fromJson(Map<String, dynamic> json) {
    final rawTierStr = json['tier'] as String? ?? 'Bronze';
    final parsedTier = RankTier.fromString(rawTierStr);

    final rawDivStr = json['division'] as String?;
    final parsedDivision = (rawDivStr != null && parsedTier.hasDivisions)
        ? RankDivision.fromString(rawDivStr)
        : (parsedTier.hasDivisions ? RankDivision.III : null);

    final rawPeakTierStr = json['peak_tier'] as String? ?? rawTierStr;
    final parsedPeakTier = RankTier.fromString(rawPeakTierStr);

    final rawPeakDivStr = json['peak_division'] as String?;
    final parsedPeakDivision = (rawPeakDivStr != null && parsedPeakTier.hasDivisions)
        ? RankDivision.fromString(rawPeakDivStr)
        : (parsedPeakTier.hasDivisions ? parsedDivision : null);

    return OnlinePlayerRank(
      userId: json['user_id'] as String? ?? '',
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      tier: parsedTier,
      division: parsedDivision,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      mmr: (json['mmr'] as num?)?.toInt() ?? 1000,
      peakTier: parsedPeakTier,
      peakDivision: parsedPeakDivision,
      peakMmr: (json['peak_mmr'] as num?)?.toInt() ?? 1000,
      winStreak: (json['win_streak'] as num?)?.toInt() ?? 0,
      longestWinStreak: (json['longest_win_streak'] as num?)?.toInt() ?? 0,
      demotionShieldActive: json['demotion_shield_active'] as bool? ?? false,
      totalRankedMatches: (json['total_ranked_matches'] as num?)?.toInt() ?? 0,
      totalRankedWins: (json['total_ranked_wins'] as num?)?.toInt() ?? 0,
      totalRankedLosses: (json['total_ranked_losses'] as num?)?.toInt() ?? 0,
      totalRankedTies: (json['total_ranked_ties'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'total_xp': totalXp,
      'tier': tier.displayName,
      'division': division?.label,
      'stars': stars,
      'mmr': mmr,
      'peak_tier': peakTier.displayName,
      'peak_division': peakDivision?.label,
      'peak_mmr': peakMmr,
      'win_streak': winStreak,
      'longest_win_streak': longestWinStreak,
      'demotion_shield_active': demotionShieldActive,
      'total_ranked_matches': totalRankedMatches,
      'total_ranked_wins': totalRankedWins,
      'total_ranked_losses': totalRankedLosses,
      'total_ranked_ties': totalRankedTies,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Server-authoritative online ranked batting & bowling career metrics.
/// Synchronized with `public.online_ranked_stats`.
class OnlineRankedStats {
  final String userId;
  final int totalRuns;
  final int totalWickets;
  final int highestScore;
  final int? bestChase;
  final DateTime? updatedAt;

  const OnlineRankedStats({
    required this.userId,
    this.totalRuns = 0,
    this.totalWickets = 0,
    this.highestScore = 0,
    this.bestChase,
    this.updatedAt,
  });

  factory OnlineRankedStats.empty(String userId) {
    return OnlineRankedStats(
      userId: userId,
      totalRuns: 0,
      totalWickets: 0,
      highestScore: 0,
      bestChase: null,
      updatedAt: DateTime.now(),
    );
  }

  factory OnlineRankedStats.fromJson(Map<String, dynamic> json) {
    return OnlineRankedStats(
      userId: json['user_id'] as String? ?? '',
      totalRuns: (json['total_runs'] as num?)?.toInt() ?? 0,
      totalWickets: (json['total_wickets'] as num?)?.toInt() ?? 0,
      highestScore: (json['highest_score'] as num?)?.toInt() ?? 0,
      bestChase: (json['best_chase'] as num?)?.toInt(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'total_runs': totalRuns,
      'total_wickets': totalWickets,
      'highest_score': highestScore,
      'best_chase': bestChase,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
