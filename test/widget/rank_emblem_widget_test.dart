import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_emblem_widget.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_stars_widget.dart';

void main() {
  group('RankEmblemWidget - Rendering & Lifecycle Tests', () {
    testWidgets('Renders all 10 rank tiers without error in static mode', (tester) async {
      for (final tier in RankTier.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RankEmblemWidget(
                  tier: tier,
                  size: 80,
                  animate: false,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(RankEmblemWidget), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('Renders all 10 rank tiers in animated mode with particle ticking', (tester) async {
      for (final tier in RankTier.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RankEmblemWidget(
                  tier: tier,
                  size: 80,
                  animate: true,
                  seed: 42,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(RankEmblemWidget), findsOneWidget);
        // Advance clock to trigger animation frames
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('Renders division badge correctly for tiered ranks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RankEmblemWidget(
                tier: RankTier.gold,
                division: RankDivision.II,
                size: 90,
                animate: false,
                showDivisionBadge: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('II'), findsOneWidget);
    });

    testWidgets('Renders stars below emblem when showStars is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RankEmblemWidget(
                tier: RankTier.platinum,
                division: RankDivision.III,
                size: 100,
                animate: false,
                showStars: true,
                stars: 2,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RankStarsWidget), findsOneWidget);
      // Platinum division has 3 stars total; 2 filled, 1 empty
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(1));
    });

    testWidgets('Master tier shows 10-star counter widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RankStarsWidget(
                tier: RankTier.master,
                stars: 7,
              ),
            ),
          ),
        ),
      );

      expect(find.text('7 / 10'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('Grand Master tier displays Apex Top 100 badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RankStarsWidget(
                tier: RankTier.grandMaster,
                stars: 0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('APEX TOP 100'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    });

    testWidgets('Respects MediaQuery disableAnimations (Reduced Motion)', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: RankEmblemWidget(
                  tier: RankTier.diamond,
                  size: 80,
                  animate: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RankEmblemWidget), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      // Does not throw and renders static fallback
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Responsive sizing: scales accurately from 32px to 160px', (tester) async {
      for (final size in [32.0, 64.0, 120.0, 160.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RankEmblemWidget(
                  tier: RankTier.proElite,
                  size: size,
                  animate: false,
                ),
              ),
            ),
          ),
        );

        final sizedBoxFinder = find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.size == Size(size, size),
        );
        expect(sizedBoxFinder, findsOneWidget);
      }
    });
  });
}
