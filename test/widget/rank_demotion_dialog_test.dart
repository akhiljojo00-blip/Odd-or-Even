import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_demotion_dialog.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_emblem_widget.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_stars_widget.dart';

void main() {
  group('RankDemotionDialog - Widget Tests', () {
    testWidgets('Renders demotion shield activated dialog with protection message', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RankDemotionDialog(
              tier: RankTier.diamond,
              division: RankDivision.III,
              stars: 0,
              shieldAbsorbed: true,
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('DEMOTION SHIELD ACTIVATED'), findsOneWidget);
      expect(find.text('DIAMOND III'), findsOneWidget);
      expect(find.textContaining('Loss absorbed by your Demotion Shield'), findsOneWidget);
      expect(find.byType(RankEmblemWidget), findsOneWidget);
      expect(find.byType(RankStarsWidget), findsOneWidget);
      expect(find.byIcon(Icons.shield_rounded), findsWidgets);
      expect(find.text('CONTINUE'), findsOneWidget);

      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('Renders rank demoted presentation cleanly and respectfully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RankDemotionDialog(
              tier: RankTier.gold,
              division: RankDivision.I,
              stars: 2,
              shieldAbsorbed: false,
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('RANK DEMOTION'), findsOneWidget);
      expect(find.text('GOLD I'), findsOneWidget);
      expect(find.textContaining('Your rank has been adjusted'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
      expect(find.byType(RankStarsWidget), findsOneWidget);
    });
  });
}
