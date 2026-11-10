/// Segregated career statistics model for individual game modes.
class ModeCareerStats {
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int matchesTied;
  final int totalRuns;
  final int totalWickets;
  final int highestScore;
  final int currentStreak;
  final int longestWinStreak;
  final int? bestChase;

  const ModeCareerStats({
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.matchesTied = 0,
    this.totalRuns = 0,
    this.totalWickets = 0,
    this.highestScore = 0,
    this.currentStreak = 0,
    this.longestWinStreak = 0,
    this.bestChase,
  });

  double get winRate =>
      matchesPlayed > 0 ? (matchesWon / matchesPlayed) * 100 : 0.0;

  double get averageRuns =>
      matchesPlayed > 0 ? (totalRuns / matchesPlayed) : 0.0;

  ModeCareerStats recordMatch({
    required bool isWin,
    required bool isTie,
    required int runsScored,
    required int wicketsTaken,
    required bool wasChasing,
    required int? target,
  }) {
    final newPlayed = matchesPlayed + 1;
    final newWon = matchesWon + (isWin ? 1 : 0);
    final newLost = matchesLost + (!isWin && !isTie ? 1 : 0);
    final newTied = matchesTied + (isTie ? 1 : 0);
    final newRuns = totalRuns + runsScored;
    final newWickets = totalWickets + wicketsTaken;
    final newHighest = runsScored > highestScore ? runsScored : highestScore;

    final newStreak = isWin ? (currentStreak >= 0 ? currentStreak + 1 : 1) : (!isTie ? (currentStreak <= 0 ? currentStreak - 1 : -1) : 0);
    final newLongestWin = newStreak > longestWinStreak ? newStreak : longestWinStreak;

    int? newBestChase = bestChase;
    if (wasChasing && isWin && target != null) {
      if (newBestChase == null || target > newBestChase) {
        newBestChase = target;
      }
    }

    return ModeCareerStats(
      matchesPlayed: newPlayed,
      matchesWon: newWon,
      matchesLost: newLost,
      matchesTied: newTied,
      totalRuns: newRuns,
      totalWickets: newWickets,
      highestScore: newHighest,
      currentStreak: newStreak,
      longestWinStreak: newLongestWin,
      bestChase: newBestChase,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchesPlayed': matchesPlayed,
      'matchesWon': matchesWon,
      'matchesLost': matchesLost,
      'matchesTied': matchesTied,
      'totalRuns': totalRuns,
      'totalWickets': totalWickets,
      'highestScore': highestScore,
      'currentStreak': currentStreak,
      'longestWinStreak': longestWinStreak,
      'bestChase': bestChase,
    };
  }

  factory ModeCareerStats.fromJson(Map<String, dynamic> json) {
    return ModeCareerStats(
      matchesPlayed: json['matchesPlayed'] as int? ?? 0,
      matchesWon: json['matchesWon'] as int? ?? 0,
      matchesLost: json['matchesLost'] as int? ?? 0,
      matchesTied: json['matchesTied'] as int? ?? 0,
      totalRuns: json['totalRuns'] as int? ?? 0,
      totalWickets: json['totalWickets'] as int? ?? 0,
      highestScore: json['highestScore'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestWinStreak: json['longestWinStreak'] as int? ?? 0,
      bestChase: json['bestChase'] as int?,
    );
  }
}
