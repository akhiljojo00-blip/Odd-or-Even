// ignore_for_file: constant_identifier_names

enum RankTier {
  bronze(
    displayName: 'Bronze',
    tierIndex: 0,
    hasDivisions: true,
    maxStars: 3,
  ),
  silver(
    displayName: 'Silver',
    tierIndex: 1,
    hasDivisions: true,
    maxStars: 3,
  ),
  gold(
    displayName: 'Gold',
    tierIndex: 2,
    hasDivisions: true,
    maxStars: 3,
  ),
  platinum(
    displayName: 'Platinum',
    tierIndex: 3,
    hasDivisions: true,
    maxStars: 3,
  ),
  diamond(
    displayName: 'Diamond',
    tierIndex: 4,
    hasDivisions: true,
    maxStars: 3,
  ),
  elite(
    displayName: 'Elite',
    tierIndex: 5,
    hasDivisions: true,
    maxStars: 3,
  ),
  proElite(
    displayName: 'Pro Elite',
    tierIndex: 6,
    hasDivisions: true,
    maxStars: 3,
  ),
  legend(
    displayName: 'Legend',
    tierIndex: 7,
    hasDivisions: true,
    maxStars: 3,
  ),
  master(
    displayName: 'Master',
    tierIndex: 8,
    hasDivisions: false,
    maxStars: 10,
  ),
  grandMaster(
    displayName: 'Grand Master',
    tierIndex: 9,
    hasDivisions: false,
    maxStars: 0,
  );

  final String displayName;
  final int tierIndex;
  final bool hasDivisions;
  final int maxStars;

  const RankTier({
    required this.displayName,
    required this.tierIndex,
    required this.hasDivisions,
    required this.maxStars,
  });

  /// Absolute floor where stars can never be lost.
  bool get hasZeroStarLoss => this == RankTier.bronze;

  /// Tiers where demotion below the tier is impossible (Tier Floor).
  bool get isTierFloor =>
      this == RankTier.bronze ||
      this == RankTier.silver ||
      this == RankTier.gold;

  /// Tiers that support Demotion Shield buffer at 0 stars before dropping a tier.
  bool get hasDemotionShield =>
      this == RankTier.platinum ||
      this == RankTier.diamond ||
      this == RankTier.elite ||
      this == RankTier.proElite ||
      this == RankTier.legend ||
      this == RankTier.master;

  /// Win streak bonus (+1 extra star on 3+ consecutive wins).
  bool get hasStreakBonus =>
      this == RankTier.bronze ||
      this == RankTier.silver ||
      this == RankTier.gold;

  RankTier? get nextTier {
    final nextIdx = tierIndex + 1;
    if (nextIdx < RankTier.values.length) {
      return RankTier.values[nextIdx];
    }
    return null;
  }

  RankTier? get previousTier {
    final prevIdx = tierIndex - 1;
    if (prevIdx >= 0) {
      return RankTier.values[prevIdx];
    }
    return null;
  }

  static RankTier fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    for (final tier in RankTier.values) {
      if (tier.name.toLowerCase() == normalized ||
          tier.displayName.toLowerCase().replaceAll(' ', '') == normalized) {
        return tier;
      }
    }
    return RankTier.bronze;
  }
}

enum RankDivision {
  III('III', 3),
  II('II', 2),
  I('I', 1);

  final String label;
  final int divisionNumber;

  const RankDivision(this.label, this.divisionNumber);

  RankDivision? get nextDivision {
    switch (this) {
      case RankDivision.III:
        return RankDivision.II;
      case RankDivision.II:
        return RankDivision.I;
      case RankDivision.I:
        return null;
    }
  }

  RankDivision? get previousDivision {
    switch (this) {
      case RankDivision.I:
        return RankDivision.II;
      case RankDivision.II:
        return RankDivision.III;
      case RankDivision.III:
        return null;
    }
  }

  static RankDivision fromString(String value) {
    switch (value.toUpperCase().trim()) {
      case 'I':
      case '1':
        return RankDivision.I;
      case 'II':
      case '2':
        return RankDivision.II;
      case 'III':
      case '3':
      default:
        return RankDivision.III;
    }
  }
}

/// Offline VS Computer Rank State.
/// Stored locally in SharedPreferences with HMAC-SHA256 signature.
class VsComputerRankState {
  final int version;
  final RankTier tier;
  final RankDivision division;
  final int stars;
  final bool demotionShieldActive;
  final RankTier peakTier;
  final RankDivision peakDivision;
  final int matchesPlayed;
  final int matchesWon;
  final int winStreak;
  final DateTime? lastPlayedAt;

  const VsComputerRankState({
    this.version = 1,
    required this.tier,
    required this.division,
    required this.stars,
    this.demotionShieldActive = false,
    required this.peakTier,
    required this.peakDivision,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.winStreak = 0,
    this.lastPlayedAt,
  });

  factory VsComputerRankState.initial() {
    return const VsComputerRankState(
      version: 1,
      tier: RankTier.bronze,
      division: RankDivision.III,
      stars: 0,
      demotionShieldActive: false,
      peakTier: RankTier.bronze,
      peakDivision: RankDivision.III,
      matchesPlayed: 0,
      matchesWon: 0,
      winStreak: 0,
    );
  }

  double get winRate =>
      matchesPlayed > 0 ? (matchesWon / matchesPlayed) * 100 : 0.0;

  String get fullRankLabel {
    if (tier.hasDivisions) {
      return '${tier.displayName} ${division.label}';
    }
    return tier.displayName;
  }

  VsComputerRankState copyWith({
    int? version,
    RankTier? tier,
    RankDivision? division,
    int? stars,
    bool? demotionShieldActive,
    RankTier? peakTier,
    RankDivision? peakDivision,
    int? matchesPlayed,
    int? matchesWon,
    int? winStreak,
    DateTime? lastPlayedAt,
  }) {
    return VsComputerRankState(
      version: version ?? this.version,
      tier: tier ?? this.tier,
      division: division ?? this.division,
      stars: stars ?? this.stars,
      demotionShieldActive: demotionShieldActive ?? this.demotionShieldActive,
      peakTier: peakTier ?? this.peakTier,
      peakDivision: peakDivision ?? this.peakDivision,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      matchesWon: matchesWon ?? this.matchesWon,
      winStreak: winStreak ?? this.winStreak,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'tier': tier.name,
      'division': division.name,
      'stars': stars,
      'demotionShieldActive': demotionShieldActive,
      'peakTier': peakTier.name,
      'peakDivision': peakDivision.name,
      'matchesPlayed': matchesPlayed,
      'matchesWon': matchesWon,
      'winStreak': winStreak,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    };
  }

  factory VsComputerRankState.fromJson(Map<String, dynamic> json) {
    final tier = RankTier.fromString(json['tier'] as String? ?? 'bronze');
    final division = RankDivision.fromString(json['division'] as String? ?? 'III');
    final peakTier = RankTier.fromString(json['peakTier'] as String? ?? tier.name);
    final peakDivision = RankDivision.fromString(json['peakDivision'] as String? ?? division.name);

    return VsComputerRankState(
      version: json['version'] as int? ?? 1,
      tier: tier,
      division: division,
      stars: json['stars'] as int? ?? 0,
      demotionShieldActive: json['demotionShieldActive'] as bool? ?? false,
      peakTier: peakTier,
      peakDivision: peakDivision,
      matchesPlayed: json['matchesPlayed'] as int? ?? 0,
      matchesWon: json['matchesWon'] as int? ?? 0,
      winStreak: json['winStreak'] as int? ?? 0,
      lastPlayedAt: json['lastPlayedAt'] != null
          ? DateTime.tryParse(json['lastPlayedAt'] as String)
          : null,
    );
  }
}
