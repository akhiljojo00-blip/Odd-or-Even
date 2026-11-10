import '../../../progression/domain/models/rank_tier.dart';

/// 10 Progressive AI difficulty tiers corresponding to offline rank tiers.
enum RankedAiTier {
  bronze('Casual Random', 'Uniform random distribution'),
  silver('Parity Aware', 'Toss parity and anti-repeat heuristic'),
  gold('Frequency Tracker', 'Tracks human pick frequency'),
  platinum('Situational Batter', 'Target chase calculations'),
  diamond('Adaptive Bowler', 'Counter-rotates human pick tendencies'),
  elite('Markov Predictor', 'Order-1 Markov chain transition matrix'),
  proElite('Entropy Counter', 'Exploits patterns and counters stall defense'),
  legend('Tactical Endgame', '3-ball recursive chase tree solver'),
  master('Psychological Profiler', 'Pressure behavior detection and exploit'),
  grandMaster('Minimax Hand Cricket', 'Game-Theoretic Nash Equilibrium mixed strategy');

  final String title;
  final String description;

  const RankedAiTier(this.title, this.description);

  static RankedAiTier fromRankTier(RankTier tier) {
    switch (tier) {
      case RankTier.bronze:
        return RankedAiTier.bronze;
      case RankTier.silver:
        return RankedAiTier.silver;
      case RankTier.gold:
        return RankedAiTier.gold;
      case RankTier.platinum:
        return RankedAiTier.platinum;
      case RankTier.diamond:
        return RankedAiTier.diamond;
      case RankTier.elite:
        return RankedAiTier.elite;
      case RankTier.proElite:
        return RankedAiTier.proElite;
      case RankTier.legend:
        return RankedAiTier.legend;
      case RankTier.master:
        return RankedAiTier.master;
      case RankTier.grandMaster:
        return RankedAiTier.grandMaster;
    }
  }
}
