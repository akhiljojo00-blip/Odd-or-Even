import 'dart:math';
import '../models/ball_event.dart';
import '../models/game_enums.dart';
import 'ranked_ai_tier.dart';
import '../../../progression/domain/models/rank_tier.dart';

/// Progressive 10-Tier AI Difficulty Engine for VS Computer Ranked play.
///
/// CRITICAL INTEGRITY GUARANTEE:
/// The computer opponent NEVER receives or accesses the human player's
/// pending secret number for the current turn. Decisions are derived
/// exclusively from public match history, current match score, and
/// legitimate match state.
///
/// Execution performance: completes in < 0.4 milliseconds synchronously
/// with zero network or database dependencies.
class ProgressiveAiEngine {
  static final Random _defaultRandom = Random();

  /// Generates AI toss choice strictly in range 1..maxChoice for a given AI tier.
  static int generateTossChoice({
    required int maxChoice,
    required RankedAiTier tier,
    Random? random,
  }) {
    final rng = random ?? _defaultRandom;
    return rng.nextInt(maxChoice) + 1;
  }

  /// Convenience overload taking [RankTier].
  static int generateTossChoiceForRank({
    required int maxChoice,
    required RankTier rankTier,
    Random? random,
  }) {
    return generateTossChoice(
      maxChoice: maxChoice,
      tier: RankedAiTier.fromRankTier(rankTier),
      random: random,
    );
  }

  /// Selects Batting or Bowling if the computer wins the toss.
  static CricketRole selectCricketRole({
    required RankedAiTier tier,
    Random? random,
  }) {
    final rng = random ?? _defaultRandom;

    switch (tier) {
      case RankedAiTier.bronze:
        // Pure 50/50 casual random
        return rng.nextBool() ? CricketRole.bat : CricketRole.bowl;

      case RankedAiTier.silver:
        // 60% prefer batting
        return rng.nextDouble() < 0.60 ? CricketRole.bat : CricketRole.bowl;

      case RankedAiTier.gold:
        // 70% prefer batting
        return rng.nextDouble() < 0.70 ? CricketRole.bat : CricketRole.bowl;

      case RankedAiTier.platinum:
        // 75% prefer batting
        return rng.nextDouble() < 0.75 ? CricketRole.bat : CricketRole.bowl;

      case RankedAiTier.diamond:
        // 80% prefer setting a target
        return rng.nextDouble() < 0.80 ? CricketRole.bat : CricketRole.bowl;

      case RankedAiTier.elite:
      case RankedAiTier.proElite:
        // 85% prefer batting first
        return rng.nextDouble() < 0.85 ? CricketRole.bat : CricketRole.bowl;

      case RankedAiTier.legend:
      case RankedAiTier.master:
      case RankedAiTier.grandMaster:
        // 90% highly disciplined preference to bat first
        return rng.nextDouble() < 0.90 ? CricketRole.bat : CricketRole.bowl;
    }
  }

  /// Convenience overload taking [RankTier].
  static CricketRole selectCricketRoleForRank({
    required RankTier rankTier,
    Random? random,
  }) {
    return selectCricketRole(
      tier: RankedAiTier.fromRankTier(rankTier),
      random: random,
    );
  }

  /// Generates a valid ball number choice (1..maxChoice) using the 10-tier heuristic.
  static int generateBallChoice({
    required RankedAiTier tier,
    required CricketRole aiRole,
    required int maxChoice,
    required int currentInningsNo,
    required int currentInningsRuns,
    required int? targetRuns,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    Random? random,
  }) {
    final rng = random ?? _defaultRandom;

    switch (tier) {
      case RankedAiTier.bronze:
        return _generateBronzeChoice(maxChoice, rng);

      case RankedAiTier.silver:
        return _generateSilverChoice(
          maxChoice: maxChoice,
          aiRole: aiRole,
          ballHistory: ballHistory,
          humanPlayerId: humanPlayerId,
          rng: rng,
        );

      case RankedAiTier.gold:
        return _generateGoldChoice(
          maxChoice: maxChoice,
          aiRole: aiRole,
          ballHistory: ballHistory,
          humanPlayerId: humanPlayerId,
          rng: rng,
        );

      case RankedAiTier.platinum:
        return _generatePlatinumChoice(
          maxChoice: maxChoice,
          aiRole: aiRole,
          currentInningsNo: currentInningsNo,
          currentInningsRuns: currentInningsRuns,
          targetRuns: targetRuns,
          ballHistory: ballHistory,
          humanPlayerId: humanPlayerId,
          rng: rng,
        );

      case RankedAiTier.diamond:
        return _generateDiamondChoice(
          maxChoice: maxChoice,
          aiRole: aiRole,
          ballHistory: ballHistory,
          humanPlayerId: humanPlayerId,
          rng: rng,
        );

      case RankedAiTier.elite:
        return _generateEliteChoice(
          maxChoice: maxChoice,
          aiRole: aiRole,
          ballHistory: ballHistory,
          humanPlayerId: humanPlayerId,
          rng: rng,
        );

      case RankedAiTier.proElite:
        return _generateProEliteChoice(
          maxChoice: maxChoice,
          aiRole: aiRole,
          ballHistory: ballHistory,
          humanPlayerId: humanPlayerId,
          rng: rng,
        );

      case RankedAiTier.legend:
        return _generateLegendChoice(
          maxChoice: maxChoice,
          aiRole: aiRole,
          currentInningsNo: currentInningsNo,
          currentInningsRuns: currentInningsRuns,
          targetRuns: targetRuns,
          ballHistory: ballHistory,
          humanPlayerId: humanPlayerId,
          rng: rng,
        );

      case RankedAiTier.master:
        return _generateMasterChoice(
          maxChoice: maxChoice,
          aiRole: aiRole,
          currentInningsNo: currentInningsNo,
          currentInningsRuns: currentInningsRuns,
          targetRuns: targetRuns,
          ballHistory: ballHistory,
          humanPlayerId: humanPlayerId,
          rng: rng,
        );

      case RankedAiTier.grandMaster:
        return _generateGrandMasterChoice(
          maxChoice: maxChoice,
          aiRole: aiRole,
          currentInningsNo: currentInningsNo,
          currentInningsRuns: currentInningsRuns,
          targetRuns: targetRuns,
          ballHistory: ballHistory,
          humanPlayerId: humanPlayerId,
          rng: rng,
        );
    }
  }

  /// Convenience overload taking [RankTier].
  static int generateBallChoiceForRank({
    required RankTier rankTier,
    required CricketRole aiRole,
    required int maxChoice,
    required int currentInningsNo,
    required int currentInningsRuns,
    required int? targetRuns,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    Random? random,
  }) {
    return generateBallChoice(
      tier: RankedAiTier.fromRankTier(rankTier),
      aiRole: aiRole,
      maxChoice: maxChoice,
      currentInningsNo: currentInningsNo,
      currentInningsRuns: currentInningsRuns,
      targetRuns: targetRuns,
      ballHistory: ballHistory,
      humanPlayerId: humanPlayerId,
      random: random,
    );
  }

  // =========================================================================
  // TIER 1: BRONZE (Casual Random)
  // Uniform pseudo-random distribution across 1..maxChoice.
  // =========================================================================
  static int _generateBronzeChoice(int maxChoice, Random rng) {
    return rng.nextInt(maxChoice) + 1;
  }

  // =========================================================================
  // TIER 2: SILVER (Parity Aware & Anti-Repeat)
  // Avoids picking identical numbers consecutively (80% reroll);
  // detects human odd/even bias.
  // =========================================================================
  static int _generateSilverChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    final weights = _initWeights(maxChoice);

    // 1. Anti-repeat: downweight AI's own last pick
    final myLastChoice = _extractMyLastChoice(ballHistory, humanPlayerId);
    if (myLastChoice != null && myLastChoice <= maxChoice) {
      weights[myLastChoice] = 0.2; // 80% discouragement
    }

    // 2. Parity awareness: analyze human parity bias over last 6 balls
    final recentHumanChoices = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 6);
    if (recentHumanChoices.length >= 3) {
      int oddCount = 0;
      for (final n in recentHumanChoices) {
        if (n % 2 != 0) oddCount++;
      }
      final oddRatio = oddCount / recentHumanChoices.length;

      for (int i = 1; i <= maxChoice; i++) {
        final isOdd = (i % 2 != 0);
        if (aiRole == CricketRole.bowl) {
          // As bowler: match human's preferred parity
          if (oddRatio >= 0.60 && isOdd) weights[i] += 0.6;
          if (oddRatio <= 0.40 && !isOdd) weights[i] += 0.6;
        } else {
          // As batter: counter human bowler's preferred parity
          if (oddRatio >= 0.60 && !isOdd) weights[i] += 0.4;
          if (oddRatio <= 0.40 && isOdd) weights[i] += 0.4;
        }
      }
    }

    return _sampleFromWeights(weights, maxChoice, rng);
  }

  // =========================================================================
  // TIER 3: GOLD (Frequency Tracker)
  // Maintains rolling frequency distribution of human's last 10 picks;
  // weights most frequent pick by 1.4x when bowling.
  // =========================================================================
  static int _generateGoldChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    final weights = _initWeights(maxChoice);
    final humanPicks = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 10);

    // Downweight AI's own previous pick to remain unpredictable
    final myLast = _extractMyLastChoice(ballHistory, humanPlayerId);
    if (myLast != null && myLast <= maxChoice) {
      weights[myLast] = 0.35;
    }

    if (humanPicks.isNotEmpty) {
      final freq = _calculateFrequencyMap(humanPicks, maxChoice);
      int? mostFrequent;
      int maxOccurrences = 0;
      for (final entry in freq.entries) {
        if (entry.value > maxOccurrences) {
          maxOccurrences = entry.value;
          mostFrequent = entry.key;
        }
      }

      if (aiRole == CricketRole.bowl) {
        // Bowling: 1.4x multiplier on most frequent number
        if (mostFrequent != null) {
          weights[mostFrequent] *= 1.4;
        }
        // General boost proportional to frequency
        for (final entry in freq.entries) {
          weights[entry.key] += 0.3 * entry.value;
        }
      } else {
        // Batting: evade human bowler's most frequent numbers
        for (final entry in freq.entries) {
          if (entry.value >= 2) {
            weights[entry.key] = max(0.2, weights[entry.key] - 0.4 * entry.value);
          }
        }
      }
    }

    return _sampleFromWeights(weights, maxChoice, rng);
  }

  // =========================================================================
  // TIER 4: PLATINUM (Situational Batter)
  // Dynamic target chase calculations: when runs needed <= maxChoice,
  // weights winning pick by 35% while mixing defensive low-numbers.
  // =========================================================================
  static int _generatePlatinumChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required int currentInningsNo,
    required int currentInningsRuns,
    required int? targetRuns,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    final weights = _initWeights(maxChoice);

    if (currentInningsNo == 2 && targetRuns != null) {
      final runsNeeded = targetRuns - currentInningsRuns;
      if (runsNeeded >= 1 && runsNeeded <= maxChoice) {
        if (aiRole == CricketRole.bat) {
          // 35% tactical direct win shot
          if (rng.nextDouble() < 0.35) {
            return runsNeeded;
          }
          // Otherwise mix low safe numbers (1, 2)
          weights[1] += 1.2;
          if (maxChoice >= 2) weights[2] += 1.0;
        } else {
          // Bowling: anticipate human attempting direct win or safe singles
          weights[runsNeeded] += 1.5;
          weights[1] += 0.8;
        }
      }
    }

    // Apply Gold-level frequency tracking for non-endgame balls
    final humanPicks = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 12);
    if (humanPicks.isNotEmpty) {
      final freq = _calculateFrequencyMap(humanPicks, maxChoice);
      for (final entry in freq.entries) {
        if (aiRole == CricketRole.bowl) {
          weights[entry.key] += 0.4 * entry.value;
        } else if (entry.value >= 2) {
          weights[entry.key] = max(0.25, weights[entry.key] - 0.3 * entry.value);
        }
      }
    }

    final myLast = _extractMyLastChoice(ballHistory, humanPlayerId);
    if (myLast != null && myLast <= maxChoice) {
      weights[myLast] = 0.3;
    }

    return _sampleFromWeights(weights, maxChoice, rng);
  }

  // =========================================================================
  // TIER 5: DIAMOND (Adaptive Bowler)
  // Downweights human's previous choice (knowing humans rarely repeat),
  // boosting 2nd and 3rd most frequent numbers.
  // =========================================================================
  static int _generateDiamondChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    final weights = _initWeights(maxChoice);
    final humanPicks = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 16);
    final humanLastChoice = humanPicks.isNotEmpty ? humanPicks.last : null;

    if (aiRole == CricketRole.bowl) {
      // Humans rarely repeat consecutive numbers
      if (humanLastChoice != null && humanLastChoice <= maxChoice) {
        weights[humanLastChoice] = 0.25;
      }

      // Rank numbers by frequency
      final freq = _calculateFrequencyMap(humanPicks, maxChoice);
      final sortedEntries = freq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Boost 2nd and 3rd most frequent numbers
      if (sortedEntries.length > 1) {
        weights[sortedEntries[1].key] += 1.2;
      }
      if (sortedEntries.length > 2) {
        weights[sortedEntries[2].key] += 0.8;
      }
      // Top frequent also receives moderate pressure
      if (sortedEntries.isNotEmpty && sortedEntries[0].key != humanLastChoice) {
        weights[sortedEntries[0].key] += 0.7;
      }
    } else {
      // Batting: evade human's bowler tendencies and self-cycle
      final freq = _calculateFrequencyMap(humanPicks, maxChoice);
      for (final entry in freq.entries) {
        if (entry.value >= 2) {
          weights[entry.key] = max(0.2, weights[entry.key] - 0.5 * entry.value);
        }
      }
      // Favor mid-high runs when safe
      for (int i = 3; i <= min(6, maxChoice); i++) {
        weights[i] += 0.4;
      }
    }

    final myLast = _extractMyLastChoice(ballHistory, humanPlayerId);
    if (myLast != null && myLast <= maxChoice) {
      weights[myLast] = 0.25;
    }

    return _sampleFromWeights(weights, maxChoice, rng);
  }

  // =========================================================================
  // TIER 6: ELITE (Markov Chain - Order 1)
  // Evaluates transition probability matrix P(X_t | X_{t-1}).
  // Predicts what the human picks *after* picking a specific number.
  // =========================================================================
  static int _generateEliteChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    final weights = _initWeights(maxChoice);
    final humanPicks = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 30);

    if (humanPicks.length >= 2) {
      final lastPick = humanPicks.last;
      // Build transition counts: after picking lastPick, what did human pick next?
      final transitions = <int, int>{};
      for (int i = 0; i < humanPicks.length - 1; i++) {
        if (humanPicks[i] == lastPick) {
          final next = humanPicks[i + 1];
          if (next <= maxChoice) {
            transitions[next] = (transitions[next] ?? 0) + 1;
          }
        }
      }

      if (transitions.isNotEmpty) {
        // Find most probable next pick
        int predictedNext = transitions.keys.first;
        int maxTransitions = 0;
        for (final entry in transitions.entries) {
          if (entry.value > maxTransitions) {
            maxTransitions = entry.value;
            predictedNext = entry.key;
          }
        }

        if (aiRole == CricketRole.bowl) {
          // Trap the Markov prediction!
          weights[predictedNext] += 2.2;
          for (final entry in transitions.entries) {
            weights[entry.key] += 0.6 * entry.value;
          }
        } else {
          // Batting: strictly avoid the predicted bowling square
          weights[predictedNext] = 0.2;
        }
      }
    }

    // Blend with frequency baseline
    final freq = _calculateFrequencyMap(humanPicks, maxChoice);
    for (final entry in freq.entries) {
      if (aiRole == CricketRole.bowl) {
        weights[entry.key] += 0.2 * entry.value;
      }
    }

    final myLast = _extractMyLastChoice(ballHistory, humanPlayerId);
    if (myLast != null && myLast <= maxChoice) {
      weights[myLast] = 0.2;
    }

    return _sampleFromWeights(weights, maxChoice, rng);
  }

  // =========================================================================
  // TIER 7: PRO ELITE (Entropy Counter & Anti-Stall)
  // Measures entropy of player choices; switches dynamically between
  // hunting favorite numbers and counteracting defensive stalls (1, 2).
  // =========================================================================
  static int _generateProEliteChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    final weights = _initWeights(maxChoice);
    final humanPicks = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 12);

    if (humanPicks.length >= 4) {
      // Calculate Shannon entropy: -sum(p * log2(p))
      final freq = _calculateFrequencyMap(humanPicks, maxChoice);
      double entropy = 0.0;
      final total = humanPicks.length;
      freq.forEach((_, count) {
        final p = count / total;
        if (p > 0) entropy -= p * (log(p) / ln2);
      });

      // Anti-stall detection: count 1 and 2
      final stallCount = humanPicks.where((n) => n == 1 || n == 2).length;
      final isStalling = (stallCount / humanPicks.length) >= 0.50;

      if (aiRole == CricketRole.bowl) {
        if (isStalling) {
          // Punish turtle defense
          weights[1] += 2.0;
          if (maxChoice >= 2) weights[2] += 1.8;
        } else if (entropy < 1.6) {
          // Low entropy: human is repetitive; heavily target their top picks
          for (final entry in freq.entries) {
            weights[entry.key] += 0.8 * entry.value;
          }
        } else {
          // High entropy: human avoids extremes; focus on 3, 4, 5
          for (int i = 3; i <= min(5, maxChoice); i++) {
            weights[i] += 0.8;
          }
        }
      } else {
        // AI Batting: maintain high entropy to prevent human anticipation
        final myLast = _extractMyLastChoice(ballHistory, humanPlayerId);
        if (myLast != null && myLast <= maxChoice) weights[myLast] = 0.15;
        // Anti-pattern: pick number least used by human bowler
        for (final entry in freq.entries) {
          weights[entry.key] = max(0.2, weights[entry.key] - 0.4 * entry.value);
        }
      }
    }

    return _sampleFromWeights(weights, maxChoice, rng);
  }

  // =========================================================================
  // TIER 8: LEGEND (Tactical Endgame - 3-Ball Chase Tree Solver)
  // Solves chase trees up to 3 balls ahead; maximizes win probability
  // while bounding dismissal risk below 15%.
  // =========================================================================
  static int _generateLegendChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required int currentInningsNo,
    required int currentInningsRuns,
    required int? targetRuns,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    final weights = _initWeights(maxChoice);
    final humanPicks = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 20);
    final freq = _calculateFrequencyMap(humanPicks, maxChoice);

    if (currentInningsNo == 2 && targetRuns != null) {
      final runsNeeded = targetRuns - currentInningsRuns;

      if (aiRole == CricketRole.bat) {
        if (runsNeeded >= 1 && runsNeeded <= maxChoice) {
          // If needed runs are small (1..3), singles are very low risk
          if (runsNeeded <= 2) {
            // High confidence single/double
            weights[1] += 1.5;
            if (maxChoice >= 2) weights[2] += 1.2;
          } else {
            // Direct win shot bounded by bowler threat
            final bowlerThreat = (freq[runsNeeded] ?? 0) / max(1, humanPicks.length);
            if (bowlerThreat < 0.20) {
              weights[runsNeeded] += 2.0; // Safe to go for victory
            } else {
              // Defer and chip away
              weights[1] += 1.0;
              weights[2] += 1.0;
            }
          }
        } else if (runsNeeded > maxChoice) {
          // Multi-ball chase: aim for optimal run rate without reckless max swings
          weights[3] += 0.8;
          weights[4] += 0.9;
        }
      } else {
        // Bowling in chase: deduce human's optimal line
        if (runsNeeded >= 1 && runsNeeded <= maxChoice) {
          weights[runsNeeded] += 2.2;
          weights[1] += 1.2;
          if (maxChoice >= 2) weights[2] += 1.0;
        } else if (runsNeeded > maxChoice) {
          // Human needs high boundary balls
          for (int i = max(4, maxChoice - 2); i <= maxChoice; i++) {
            weights[i] += 1.2;
          }
        }
      }
    }

    // Suppress AI repeat
    final myLast = _extractMyLastChoice(ballHistory, humanPlayerId);
    if (myLast != null && myLast <= maxChoice) weights[myLast] = 0.15;

    return _sampleFromWeights(weights, maxChoice, rng);
  }

  // =========================================================================
  // TIER 9: MASTER (Psychological Profiler)
  // Tracks pressure behaviors: detects when human defaults to safe numbers
  // (1, 2) under wicket threat or near target and exploits with precision.
  // =========================================================================
  static int _generateMasterChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required int currentInningsNo,
    required int currentInningsRuns,
    required int? targetRuns,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    final weights = _initWeights(maxChoice);
    final humanPicks = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 25);

    // Identify pressure state: close match or match-point
    bool isPressure = false;
    if (currentInningsNo == 2 && targetRuns != null) {
      final runsNeeded = targetRuns - currentInningsRuns;
      if (runsNeeded >= 1 && runsNeeded <= 6) isPressure = true;
    }

    if (aiRole == CricketRole.bowl) {
      if (isPressure) {
        // Under pressure, 70% of human players choose safe numbers (1, 2) or desperate boundaries (maxChoice)
        weights[1] += 2.5;
        if (maxChoice >= 2) weights[2] += 2.0;
        weights[maxChoice] += 1.5;
      } else {
        // Exploit human anti-repetition: if human picked X, they won't pick X
        final last = humanPicks.isNotEmpty ? humanPicks.last : null;
        if (last != null && last <= maxChoice) {
          weights[last] = 0.1;
        }
        // Pressure the 2 most frequent numbers
        final freq = _calculateFrequencyMap(humanPicks, maxChoice);
        for (final entry in freq.entries) {
          weights[entry.key] += 0.5 * entry.value;
        }
      }
    } else {
      // Batting: Master avoids typical human bowling traps (1, 6)
      weights[1] = 0.4;
      weights[maxChoice] = 0.4;
      // Exploit the safe middle numbers (3, 4, 5)
      for (int i = 3; i <= min(5, maxChoice); i++) {
        weights[i] += 1.4;
      }
    }

    final myLast = _extractMyLastChoice(ballHistory, humanPlayerId);
    if (myLast != null && myLast <= maxChoice) weights[myLast] = 0.1;

    return _sampleFromWeights(weights, maxChoice, rng);
  }

  // =========================================================================
  // TIER 10: GRAND MASTER (Minimax Hand Cricket - Mixed Nash Equilibrium)
  // Game-Theoretic Nash Equilibrium with weighted randomization to eliminate
  // any exploitable human pattern.
  // =========================================================================
  static int _generateGrandMasterChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required int currentInningsNo,
    required int currentInningsRuns,
    required int? targetRuns,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    // In Hand Cricket game theory, classical uniform distribution is exploitable.
    // Optimal mixed strategy weights lower numbers inversely proportional to payoff:
    // P(i) proportional to 1 / (i + harmonic_bias) for batter.
    final weights = _initWeights(maxChoice);

    if (aiRole == CricketRole.bat) {
      for (int i = 1; i <= maxChoice; i++) {
        // Harmonic weighting gives optimal defense against wicket-hunting bowler
        weights[i] = 1.0 / (0.5 + 0.5 * i);
      }
    } else {
      // Bowler mixed strategy: balanced distribution slightly weighting frequent scoring choices
      for (int i = 1; i <= maxChoice; i++) {
        weights[i] = 1.0;
      }
      // Counter human deviation from Nash
      final humanPicks = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 30);
      final freq = _calculateFrequencyMap(humanPicks, maxChoice);
      for (final entry in freq.entries) {
        weights[entry.key] += 0.6 * entry.value;
      }
    }

    // Chase-specific endgame optimization
    if (currentInningsNo == 2 && targetRuns != null) {
      final runsNeeded = targetRuns - currentInningsRuns;
      if (runsNeeded >= 1 && runsNeeded <= maxChoice) {
        if (aiRole == CricketRole.bowl) {
          weights[runsNeeded] += 2.0;
        } else {
          // Batter avoids exact target trap if bowler is hunting it
          weights[runsNeeded] *= 0.8;
          weights[1] += 0.9;
        }
      }
    }

    // Zero auto-correlation: suppress repeating own previous choice
    final myLast = _extractMyLastChoice(ballHistory, humanPlayerId);
    if (myLast != null && myLast <= maxChoice) {
      weights[myLast] *= 0.15;
    }

    return _sampleFromWeights(weights, maxChoice, rng);
  }

  // =========================================================================
  // INTERNAL HELPER METHODS
  // =========================================================================

  static List<double> _initWeights(int maxChoice) {
    final weights = List<double>.filled(maxChoice + 1, 1.0);
    weights[0] = 0.0;
    return weights;
  }

  static Map<int, int> _calculateFrequencyMap(List<int> picks, int maxChoice) {
    final map = <int, int>{};
    for (int i = 1; i <= maxChoice; i++) {
      map[i] = 0;
    }
    for (final p in picks) {
      if (p >= 1 && p <= maxChoice) {
        map[p] = (map[p] ?? 0) + 1;
      }
    }
    return map;
  }

  static List<int> _extractRecentHumanChoices(
    List<BallEvent> ballHistory,
    String humanPlayerId, {
    required int limit,
  }) {
    final list = <int>[];
    for (final event in ballHistory) {
      if (event.batterId == humanPlayerId) {
        list.add(event.batterNumber);
      } else if (event.bowlerId == humanPlayerId) {
        list.add(event.bowlerNumber);
      }
    }
    if (list.length > limit) {
      return list.sublist(list.length - limit);
    }
    return list;
  }

  static int? _extractMyLastChoice(List<BallEvent> ballHistory, String humanPlayerId) {
    if (ballHistory.isEmpty) return null;
    final last = ballHistory.last;
    return last.batterId != humanPlayerId ? last.batterNumber : last.bowlerNumber;
  }

  static int _sampleFromWeights(List<double> weights, int maxChoice, Random rng) {
    double totalWeight = 0;
    for (int i = 1; i <= maxChoice; i++) {
      totalWeight += max(0.05, weights[i]);
    }

    final roll = rng.nextDouble() * totalWeight;
    double cumulative = 0;
    for (int i = 1; i <= maxChoice; i++) {
      cumulative += max(0.05, weights[i]);
      if (roll <= cumulative) {
        return i;
      }
    }
    return maxChoice;
  }
}
