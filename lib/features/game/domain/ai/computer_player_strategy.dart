import 'dart:math';
import '../models/ball_event.dart';
import '../models/game_enums.dart';

enum AiDifficulty {
  easy,
  medium,
  hard;

  String get label {
    switch (this) {
      case AiDifficulty.easy:
        return 'Easy';
      case AiDifficulty.medium:
        return 'Medium';
      case AiDifficulty.hard:
        return 'Hard';
    }
  }

  String get description {
    switch (this) {
      case AiDifficulty.easy:
        return 'Casual, fully randomized choices';
      case AiDifficulty.medium:
        return 'Balanced tactical play with situational awareness';
      case AiDifficulty.hard:
        return 'Advanced pattern counter-strategy & endgame focus';
    }
  }
}

/// Local heuristic-based computer opponent strategy.
///
/// CRITICAL INTEGRITY GUARANTEE:
/// The computer opponent NEVER receives or accesses the human player's
/// pending secret number for the current turn. Decisions are derived
/// exclusively from public match history, current match score, and
/// legitimate match state.
class ComputerPlayerStrategy {
  static final Random _defaultRandom = Random();

  /// Generates AI toss number choice strictly in range 1..maxChoice.
  static int generateTossChoice({
    required int maxChoice,
    required AiDifficulty difficulty,
    Random? random,
  }) {
    final rng = random ?? _defaultRandom;
    return rng.nextInt(maxChoice) + 1;
  }

  /// Selects Batting or Bowling if the computer wins the toss.
  static CricketRole selectCricketRole({
    required AiDifficulty difficulty,
    Random? random,
  }) {
    final rng = random ?? _defaultRandom;

    switch (difficulty) {
      case AiDifficulty.easy:
        // Pure 50/50 toss decision
        return rng.nextBool() ? CricketRole.bat : CricketRole.bowl;

      case AiDifficulty.medium:
        // Cricket standard preference: 75% choose to bat first
        return rng.nextDouble() < 0.75 ? CricketRole.bat : CricketRole.bowl;

      case AiDifficulty.hard:
        // Highly strategic: 85% choose to set a benchmark target
        return rng.nextDouble() < 0.85 ? CricketRole.bat : CricketRole.bowl;
    }
  }

  /// Generates a valid ball number choice (1..maxChoice) based on difficulty and public state.
  static int generateBallChoice({
    required AiDifficulty difficulty,
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

    switch (difficulty) {
      case AiDifficulty.easy:
        return _generateEasyChoice(maxChoice, rng);

      case AiDifficulty.medium:
        return _generateMediumChoice(
          maxChoice: maxChoice,
          aiRole: aiRole,
          currentInningsNo: currentInningsNo,
          currentInningsRuns: currentInningsRuns,
          targetRuns: targetRuns,
          ballHistory: ballHistory,
          humanPlayerId: humanPlayerId,
          rng: rng,
        );

      case AiDifficulty.hard:
        return _generateHardChoice(
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

  // ---------------- EASY ----------------
  static int _generateEasyChoice(int maxChoice, Random rng) {
    return rng.nextInt(maxChoice) + 1;
  }

  // ---------------- MEDIUM ----------------
  static int _generateMediumChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required int currentInningsNo,
    required int currentInningsRuns,
    required int? targetRuns,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    // 1. In chase: if batting and needed runs are within range, tactically weight the winning number
    if (aiRole == CricketRole.bat && currentInningsNo == 2 && targetRuns != null) {
      final runsNeeded = targetRuns - currentInningsRuns;
      if (runsNeeded >= 1 && runsNeeded <= maxChoice) {
        if (rng.nextDouble() < 0.35) {
          return runsNeeded;
        }
      }
    }

    // 2. Bowling: inspect human's last 3 public choices from completed balls
    final recentHumanChoices = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 3);
    if (aiRole == CricketRole.bowl && recentHumanChoices.isNotEmpty) {
      // 30% chance to target one of the human's recent numbers to hunt for a wicket
      if (rng.nextDouble() < 0.30) {
        final candidate = recentHumanChoices[rng.nextInt(recentHumanChoices.length)];
        if (candidate >= 1 && candidate <= maxChoice) {
          return candidate;
        }
      }
    }

    // 3. Avoid excessive repetition: discourage repeating own last ball pick
    final myLastChoice = _extractMyLastChoice(ballHistory, humanPlayerId);
    int pick = rng.nextInt(maxChoice) + 1;
    if (myLastChoice != null && pick == myLastChoice && maxChoice > 1 && rng.nextDouble() < 0.70) {
      // Reroll to avoid being predictable
      pick = rng.nextInt(maxChoice) + 1;
    }

    return pick;
  }

  // ---------------- HARD ----------------
  static int _generateHardChoice({
    required int maxChoice,
    required CricketRole aiRole,
    required int currentInningsNo,
    required int currentInningsRuns,
    required int? targetRuns,
    required List<BallEvent> ballHistory,
    required String humanPlayerId,
    required Random rng,
  }) {
    final weights = List<double>.filled(maxChoice + 1, 1.0); // 1-based indexing
    weights[0] = 0.0; // Index 0 unused

    // 1. Analyze human historical choices across the match
    final allHumanChoices = _extractRecentHumanChoices(ballHistory, humanPlayerId, limit: 100);
    final humanLastChoice = allHumanChoices.isNotEmpty ? allHumanChoices.last : null;

    if (aiRole == CricketRole.bowl) {
      // --- AI IS BOWLING (Trying to match human choice to take a wicket) ---
      // Psychological insight: Humans rarely choose the identical number consecutively.
      if (humanLastChoice != null && humanLastChoice >= 1 && humanLastChoice <= maxChoice) {
        weights[humanLastChoice] = 0.35; // Downweight repeating the last pick
      }

      // Boost weights of numbers the human historically favors
      for (final choice in allHumanChoices) {
        if (choice >= 1 && choice <= maxChoice) {
          weights[choice] += 0.8;
        }
      }

      // In chase: if human batter is close to target, they frequently pick small runs or exact remainder
      if (currentInningsNo == 2 && targetRuns != null) {
        final runsNeeded = targetRuns - currentInningsRuns;
        if (runsNeeded >= 1 && runsNeeded <= maxChoice) {
          weights[runsNeeded] += 2.0;
        }
        if (runsNeeded <= 3) {
          for (int r = 1; r <= min(runsNeeded, maxChoice); r++) {
            weights[r] += 1.5;
          }
        }
      }
    } else {
      // --- AI IS BATTING (Trying to score runs while avoiding the bowler) ---
      // In chase: determine safest path to target
      if (currentInningsNo == 2 && targetRuns != null) {
        final runsNeeded = targetRuns - currentInningsRuns;
        if (runsNeeded >= 1 && runsNeeded <= maxChoice) {
          // Moderate chance to go for the win directly, but balance against being trapped
          weights[runsNeeded] += 1.5;
        }
      }

      // Avoid predictability: downweight our own last pick
      final myLastChoice = _extractMyLastChoice(ballHistory, humanPlayerId);
      if (myLastChoice != null && myLastChoice >= 1 && myLastChoice <= maxChoice) {
        weights[myLastChoice] = 0.4;
      }

      // If human bowler heavily favors certain numbers, downweight those to avoid wickets
      final bowlerCounts = <int, int>{};
      for (final choice in allHumanChoices) {
        if (choice >= 1 && choice <= maxChoice) {
          bowlerCounts[choice] = (bowlerCounts[choice] ?? 0) + 1;
        }
      }
      bowlerCounts.forEach((choice, count) {
        if (count >= 2) {
          weights[choice] = max(0.3, weights[choice] - 0.5 * count);
        }
      });
    }

    return _sampleFromWeights(weights, maxChoice, rng);
  }

  // ---------------- HELPERS ----------------

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
      totalWeight += max(0.1, weights[i]);
    }

    final roll = rng.nextDouble() * totalWeight;
    double cumulative = 0;
    for (int i = 1; i <= maxChoice; i++) {
      cumulative += max(0.1, weights[i]);
      if (roll <= cumulative) {
        return i;
      }
    }
    return maxChoice;
  }
}
