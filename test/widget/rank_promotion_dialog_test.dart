import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_emblem_widget.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_promotion_dialog.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_stars_widget.dart';

void main() {
  group('RankPromotionDialog - Widget Tests', () {
    testWidgets('Renders division promotion dialog with old and new ranks, stars, and XP pill', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RankPromotionDialog(
              previousTier: RankTier.bronze,
              previousDivision: RankDivision.III,
              newTier: RankTier.bronze,
              newDivision: RankDivision.II,
              newStars: 1,
              xpReward: 50,
              isTierPromotion: false,
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      // Advance entrance animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('PROMOTION!'), findsOneWidget);
      expect(find.text('BRONZE II'), findsOneWidget);
      expect(find.text('Bronze'), findsOneWidget); // Previous label
      expect(find.text('+50 XP PROMOTION BONUS'), findsOneWidget);
      expect(find.byType(RankEmblemWidget), findsNWidgets(2)); // Old emblem and new emblem
      expect(find.byType(RankStarsWidget), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);

      // Tap CONTINUE button
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('Renders tier promotion dialog with tier promotion badge header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RankPromotionDialog(
              previousTier: RankTier.gold,
              previousDivision: RankDivision.I,
              newTier: RankTier.platinum,
              newDivision: RankDivision.III,
              newStars: 0,
              xpReward: 50,
              isTierPromotion: true,
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('TIER PROMOTION!'), findsOneWidget);
      expect(find.text('PLATINUM III'), findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });
  });
}
