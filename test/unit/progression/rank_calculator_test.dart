import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/progression/domain/logic/rank_calculator.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';

void main() {
  group('RankCalculator - Domain Logic Unit Tests', () {
    test('Initial rank state begins at Bronze III with 0 stars and 0 streak', () {
      final initial = VsComputerRankState.initial();
      expect(initial.tier, equals(RankTier.bronze));
      expect(initial.division, equals(RankDivision.III));
      expect(initial.stars, equals(0));
      expect(initial.winStreak, equals(0));
      expect(initial.peakTier, equals(RankTier.bronze));
      expect(initial.peakDivision, equals(RankDivision.III));
      expect(initial.demotionShieldActive, isFalse);
    });

    test('Bronze never loses stars on match loss (zero-star loss rule)', () {
      final stateWithStars = VsComputerRankState.initial().copyWith(stars: 2, winStreak: 3);

      final transition = RankCalculator.computeTransition(
        current: stateWithStars,
        outcome: MatchOutcome.loss,
      );

      expect(transition.newState.tier, equals(RankTier.bronze));
      expect(transition.newState.division, equals(RankDivision.III));
      expect(transition.newState.stars, equals(2)); // Bronze maintains stars on loss
      expect(transition.starsDelta, equals(0));
      expect(transition.newState.winStreak, equals(0)); // Streak reset on loss
    });

    test('Bronze / Silver / Gold receive streak bonus (+2 stars) on 3+ consecutive wins', () {
      // 2 wins already, 3rd win incoming -> streak becomes 3
      final state = VsComputerRankState.initial().copyWith(
        stars: 0,
        winStreak: 2,
      );

      final transition = RankCalculator.computeTransition(
        current: state,
        outcome: MatchOutcome.win,
      );

      expect(transition.newState.winStreak, equals(3));
      expect(transition.newState.stars, equals(2)); // +1 standard, +1 streak bonus = +2
      expect(transition.starsDelta, equals(2));
    });

    test('Division promotion carries star overflow (Bronze III -> Bronze II)', () {
      // 2 stars in Bronze III, win with streak bonus (+2 stars) -> total 4 -> Bronze II with 1 star
      final state = VsComputerRankState.initial().copyWith(
        stars: 2,
        winStreak: 2,
      );

      final transition = RankCalculator.computeTransition(
        current: state,
        outcome: MatchOutcome.win,
      );

      expect(transition.newState.tier, equals(RankTier.bronze));
      expect(transition.newState.division, equals(RankDivision.II));
      expect(transition.newState.stars, equals(1)); // 4 - 3 = 1 overflow
      expect(transition.isDivisionPromotion, isTrue);
      expect(transition.isTierPromotion, isFalse);
    });

    test('Tier promotion from Division I to next Tier Division III', () {
      // Bronze I with 2 stars wins 1 star -> Silver III with 0 stars
      final state = VsComputerRankState.initial().copyWith(
        tier: RankTier.bronze,
        division: RankDivision.I,
        stars: 2,
        winStreak: 0,
      );

      final transition = RankCalculator.computeTransition(
        current: state,
        outcome: MatchOutcome.win,
      );

      expect(transition.newState.tier, equals(RankTier.silver));
      expect(transition.newState.division, equals(RankDivision.III));
      expect(transition.newState.stars, equals(0));
      expect(transition.isTierPromotion, isTrue);
      expect(transition.newState.peakTier, equals(RankTier.silver));
    });

    test('Tier floors prevent demotion below Silver and Gold', () {
      final silverFloor = VsComputerRankState.initial().copyWith(
        tier: RankTier.silver,
        division: RankDivision.III,
        stars: 0,
      );

      final transition = RankCalculator.computeTransition(
        current: silverFloor,
        outcome: MatchOutcome.loss,
      );

      // Cannot demote to Bronze
      expect(transition.newState.tier, equals(RankTier.silver));
      expect(transition.newState.division, equals(RankDivision.III));
      expect(transition.newState.stars, equals(0));
      expect(transition.starsDelta, equals(0));
    });

    test('Demotion Shield absorbs first loss at 0 stars for Platinum', () {
      final platinumZeroStars = VsComputerRankState.initial().copyWith(
        tier: RankTier.platinum,
        division: RankDivision.III,
        stars: 0,
        demotionShieldActive: false,
      );

      // First loss activates shield and absorbs the demotion
      final transition1 = RankCalculator.computeTransition(
        current: platinumZeroStars,
        outcome: MatchOutcome.loss,
      );

      expect(transition1.newState.tier, equals(RankTier.platinum));
      expect(transition1.newState.division, equals(RankDivision.III));
      expect(transition1.newState.stars, equals(0));
      expect(transition1.newState.demotionShieldActive, isTrue);
      expect(transition1.shieldSaved, isTrue);
      expect(transition1.isDemotion, isFalse);

      // Second consecutive loss with shield active triggers demotion to Gold I
      final transition2 = RankCalculator.computeTransition(
        current: transition1.newState,
        outcome: MatchOutcome.loss,
      );

      expect(transition2.newState.tier, equals(RankTier.gold));
      expect(transition2.newState.division, equals(RankDivision.I));
      expect(transition2.newState.stars, equals(2)); // Demoted with 2 stars
      expect(transition2.newState.demotionShieldActive, isFalse);
      expect(transition2.isDemotion, isTrue);
    });

    test('Master tier has no divisions and promotes to Grand Master upon winning 10th star', () {
      final masterState = VsComputerRankState.initial().copyWith(
        tier: RankTier.master,
        division: RankDivision.I,
        stars: 8,
      );

      final transition1 = RankCalculator.computeTransition(
        current: masterState,
        outcome: MatchOutcome.win,
      );

      expect(transition1.newState.tier, equals(RankTier.master));
      expect(transition1.newState.stars, equals(9));

      final transition2 = RankCalculator.computeTransition(
        current: transition1.newState,
        outcome: MatchOutcome.win,
      );

      expect(transition2.newState.tier, equals(RankTier.grandMaster));
      expect(transition2.newState.stars, equals(0));
      expect(transition2.isTierPromotion, isTrue);
    });

    test('Ties do not alter stars or break win streaks', () {
      final state = VsComputerRankState.initial().copyWith(
        tier: RankTier.gold,
        division: RankDivision.II,
        stars: 2,
        winStreak: 4,
      );

      final transition = RankCalculator.computeTransition(
        current: state,
        outcome: MatchOutcome.tie,
      );

      expect(transition.newState.stars, equals(2));
      expect(transition.newState.winStreak, equals(4)); // Preserved on tie
      expect(transition.starsDelta, equals(0));
    });

    test('Peak division tracking updates when climbing within same tier', () {
      final state = VsComputerRankState.initial().copyWith(
        tier: RankTier.silver,
        division: RankDivision.III,
        peakTier: RankTier.silver,
        peakDivision: RankDivision.III,
        stars: 2,
      );

      final transition = RankCalculator.computeTransition(
        current: state,
        outcome: MatchOutcome.win,
      );

      expect(transition.newState.division, equals(RankDivision.II));
      expect(transition.newState.peakDivision, equals(RankDivision.II));
    });
  });
}
