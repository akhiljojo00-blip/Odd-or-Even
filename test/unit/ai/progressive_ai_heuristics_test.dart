import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/game/domain/ai/progressive_ai_engine.dart';
import 'package:odd_or_even/features/game/domain/ai/ranked_ai_tier.dart';
import 'package:odd_or_even/features/game/domain/models/ball_event.dart';
import 'package:odd_or_even/features/game/domain/models/game_enums.dart';

void main() {
  group('ProgressiveAiEngine - 10-Tier Heuristics & Performance Tests', () {
    const humanId = 'human_player_1';
    const aiId = 'ai_bot';

    test('All 10 tiers generate legal toss and ball choices strictly within 1..maxChoice (6 and 10)', () {
      final rng = Random(42);

      for (final tier in RankedAiTier.values) {
        for (final maxChoice in [6, 10]) {
          // Toss test
          for (int i = 0; i < 20; i++) {
            final toss = ProgressiveAiEngine.generateTossChoice(
              maxChoice: maxChoice,
              tier: tier,
              random: rng,
            );
            expect(toss, inInclusiveRange(1, maxChoice), reason: '$tier toss out of range');
          }

          // Ball test as batter and bowler
          for (final role in [CricketRole.bat, CricketRole.bowl]) {
            for (int i = 0; i < 20; i++) {
              final choice = ProgressiveAiEngine.generateBallChoice(
                tier: tier,
                aiRole: role,
                maxChoice: maxChoice,
                currentInningsNo: 1,
                currentInningsRuns: 15,
                targetRuns: null,
                ballHistory: [],
                humanPlayerId: humanId,
                random: rng,
              );
              expect(choice, inInclusiveRange(1, maxChoice), reason: '$tier ball choice out of range');
            }
          }
        }
      }
    });

    test('All 10 tiers return valid cricket roles for toss decisions', () {
      final rng = Random(123);
      for (final tier in RankedAiTier.values) {
        final role = ProgressiveAiEngine.selectCricketRole(tier: tier, random: rng);
        expect(role == CricketRole.bat || role == CricketRole.bowl, isTrue);
      }
    });

    test('Silver tier avoids picking identical number consecutively (anti-repeat)', () {
      final rng = Random(77);
      // History where AI's previous ball choice was 4
      final history = [
        const BallEvent(
          inningsNo: 1,
          ballNo: 1,
          batterId: aiId,
          bowlerId: humanId,
          batterNumber: 4,
          bowlerNumber: 2,
          runsScored: 4,
          isWicket: false,
          cumulativeRuns: 4,
        ),
      ];

      int repeatCount = 0;
      const iterations = 100;
      for (int i = 0; i < iterations; i++) {
        final choice = ProgressiveAiEngine.generateBallChoice(
          tier: RankedAiTier.silver,
          aiRole: CricketRole.bat,
          maxChoice: 6,
          currentInningsNo: 1,
          currentInningsRuns: 4,
          targetRuns: null,
          ballHistory: history,
          humanPlayerId: humanId,
          random: rng,
        );
        if (choice == 4) repeatCount++;
      }

      // Expected: 4 is heavily downweighted (0.2 vs 1.0), so repeatCount should be well below 20%
      expect(repeatCount, lessThan(20));
    });

    test('Gold tier bowling weights human favorite pick by 1.4x', () {
      final rng = Random(99);
      // Human predominantly picked 5 (5 times out of 6 balls)
      final history = List<BallEvent>.generate(6, (index) {
        final pick = index < 5 ? 5 : 2;
        return BallEvent(
          inningsNo: 1,
          ballNo: index + 1,
          batterId: humanId,
          bowlerId: aiId,
          batterNumber: pick,
          bowlerNumber: 1,
          runsScored: pick,
          isWicket: false,
          cumulativeRuns: (index + 1) * 4,
        );
      });

      int fiveCount = 0;
      const iterations = 200;
      for (int i = 0; i < iterations; i++) {
        final choice = ProgressiveAiEngine.generateBallChoice(
          tier: RankedAiTier.gold,
          aiRole: CricketRole.bowl,
          maxChoice: 6,
          currentInningsNo: 1,
          currentInningsRuns: 27,
          targetRuns: null,
          ballHistory: history,
          humanPlayerId: humanId,
          random: rng,
        );
        if (choice == 5) fiveCount++;
      }

      // 5 has weight boosted significantly, should be sampled much more than uniform 1/6 (33)
      expect(fiveCount, greaterThan(60));
    });

    test('Platinum tier batting in chase tactically attempts direct win shot', () {
      final rng = Random(55);
      // Chasing target of 24, current runs = 20. Runs needed = 4 <= maxChoice (6)
      int winningChoiceCount = 0;
      const iterations = 200;

      for (int i = 0; i < iterations; i++) {
        final choice = ProgressiveAiEngine.generateBallChoice(
          tier: RankedAiTier.platinum,
          aiRole: CricketRole.bat,
          maxChoice: 6,
          currentInningsNo: 2,
          currentInningsRuns: 20,
          targetRuns: 24,
          ballHistory: [],
          humanPlayerId: humanId,
          random: rng,
        );
        if (choice == 4) winningChoiceCount++;
      }

      // 35% direct shot + weight sampling gives > 30% frequency for 4
      expect(winningChoiceCount, greaterThan(60));
    });

    test('Diamond tier downweights human last choice and boosts 2nd/3rd most frequent', () {
      final rng = Random(33);
      // Human history: picked 6 three times, 3 twice, 2 once. Last pick was 6.
      final history = [
        const BallEvent(inningsNo: 1, ballNo: 1, batterId: humanId, bowlerId: aiId, batterNumber: 6, bowlerNumber: 1, runsScored: 6, isWicket: false, cumulativeRuns: 6),
        const BallEvent(inningsNo: 1, ballNo: 2, batterId: humanId, bowlerId: aiId, batterNumber: 3, bowlerNumber: 1, runsScored: 3, isWicket: false, cumulativeRuns: 9),
        const BallEvent(inningsNo: 1, ballNo: 3, batterId: humanId, bowlerId: aiId, batterNumber: 6, bowlerNumber: 1, runsScored: 6, isWicket: false, cumulativeRuns: 15),
        const BallEvent(inningsNo: 1, ballNo: 4, batterId: humanId, bowlerId: aiId, batterNumber: 3, bowlerNumber: 1, runsScored: 3, isWicket: false, cumulativeRuns: 18),
        const BallEvent(inningsNo: 1, ballNo: 5, batterId: humanId, bowlerId: aiId, batterNumber: 2, bowlerNumber: 1, runsScored: 2, isWicket: false, cumulativeRuns: 20),
        const BallEvent(inningsNo: 1, ballNo: 6, batterId: humanId, bowlerId: aiId, batterNumber: 6, bowlerNumber: 1, runsScored: 6, isWicket: false, cumulativeRuns: 26), // Last pick was 6!
      ];

      int sixCount = 0;
      int threeCount = 0;
      const iterations = 200;

      for (int i = 0; i < iterations; i++) {
        final choice = ProgressiveAiEngine.generateBallChoice(
          tier: RankedAiTier.diamond,
          aiRole: CricketRole.bowl,
          maxChoice: 6,
          currentInningsNo: 1,
          currentInningsRuns: 26,
          targetRuns: null,
          ballHistory: history,
          humanPlayerId: humanId,
          random: rng,
        );
        if (choice == 6) sixCount++;
        if (choice == 3) threeCount++;
      }

      // 6 is downweighted as consecutive pick, while 3 (2nd frequent) is boosted
      expect(threeCount, greaterThan(sixCount));
    });

    test('Elite tier detects Order-1 Markov transitions and targets predicted next number', () {
      final rng = Random(88);
      // Transition pattern: Whenever human picks 2, next pick is 5
      final history = [
        const BallEvent(inningsNo: 1, ballNo: 1, batterId: humanId, bowlerId: aiId, batterNumber: 2, bowlerNumber: 1, runsScored: 2, isWicket: false, cumulativeRuns: 2),
        const BallEvent(inningsNo: 1, ballNo: 2, batterId: humanId, bowlerId: aiId, batterNumber: 5, bowlerNumber: 1, runsScored: 5, isWicket: false, cumulativeRuns: 7),
        const BallEvent(inningsNo: 1, ballNo: 3, batterId: humanId, bowlerId: aiId, batterNumber: 2, bowlerNumber: 1, runsScored: 2, isWicket: false, cumulativeRuns: 9),
        const BallEvent(inningsNo: 1, ballNo: 4, batterId: humanId, bowlerId: aiId, batterNumber: 5, bowlerNumber: 1, runsScored: 5, isWicket: false, cumulativeRuns: 14),
        const BallEvent(inningsNo: 1, ballNo: 5, batterId: humanId, bowlerId: aiId, batterNumber: 2, bowlerNumber: 1, runsScored: 2, isWicket: false, cumulativeRuns: 16), // Human just picked 2!
      ];

      int fiveCount = 0;
      const iterations = 100;
      for (int i = 0; i < iterations; i++) {
        final choice = ProgressiveAiEngine.generateBallChoice(
          tier: RankedAiTier.elite,
          aiRole: CricketRole.bowl,
          maxChoice: 6,
          currentInningsNo: 1,
          currentInningsRuns: 16,
          targetRuns: null,
          ballHistory: history,
          humanPlayerId: humanId,
          random: rng,
        );
        if (choice == 5) fiveCount++;
      }

      // Markov transition strongly predicts 5
      expect(fiveCount, greaterThan(35));
    });

    test('Pro Elite detects defensive stall (1, 2 spam) and aggressively punishes it', () {
      final rng = Random(11);
      // Human has spammed [1, 2, 1, 2]
      final history = [
        const BallEvent(inningsNo: 1, ballNo: 1, batterId: humanId, bowlerId: aiId, batterNumber: 1, bowlerNumber: 6, runsScored: 1, isWicket: false, cumulativeRuns: 1),
        const BallEvent(inningsNo: 1, ballNo: 2, batterId: humanId, bowlerId: aiId, batterNumber: 2, bowlerNumber: 6, runsScored: 2, isWicket: false, cumulativeRuns: 3),
        const BallEvent(inningsNo: 1, ballNo: 3, batterId: humanId, bowlerId: aiId, batterNumber: 1, bowlerNumber: 6, runsScored: 1, isWicket: false, cumulativeRuns: 4),
        const BallEvent(inningsNo: 1, ballNo: 4, batterId: humanId, bowlerId: aiId, batterNumber: 2, bowlerNumber: 6, runsScored: 2, isWicket: false, cumulativeRuns: 6),
      ];

      int stallCounterPicks = 0;
      const iterations = 100;
      for (int i = 0; i < iterations; i++) {
        final choice = ProgressiveAiEngine.generateBallChoice(
          tier: RankedAiTier.proElite,
          aiRole: CricketRole.bowl,
          maxChoice: 6,
          currentInningsNo: 1,
          currentInningsRuns: 6,
          targetRuns: null,
          ballHistory: history,
          humanPlayerId: humanId,
          random: rng,
        );
        if (choice == 1 || choice == 2) stallCounterPicks++;
      }

      // Bowler should punish with 1 or 2 at high frequency (> 50%)
      expect(stallCounterPicks, greaterThan(50));
    });

    test('Performance SLA: 1,000 AI decisions execute in under 50ms (< 0.05 ms/call)', () {
      final stopwatch = Stopwatch()..start();
      final rng = Random(12345);

      for (int i = 0; i < 1000; i++) {
        final tier = RankedAiTier.values[i % RankedAiTier.values.length];
        ProgressiveAiEngine.generateBallChoice(
          tier: tier,
          aiRole: (i % 2 == 0) ? CricketRole.bat : CricketRole.bowl,
          maxChoice: 6,
          currentInningsNo: 2,
          currentInningsRuns: 10 + (i % 20),
          targetRuns: 25,
          ballHistory: [],
          humanPlayerId: humanId,
          random: rng,
        );
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: 'AI must execute within strict < 0.4ms SLA (1000 in < 50ms)');
    });
  });
}
