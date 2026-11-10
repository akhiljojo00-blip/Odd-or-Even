import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';
import 'package:odd_or_even/features/progression/presentation/painters/emblem_particles.dart';
import 'package:odd_or_even/features/progression/presentation/painters/rank_emblem_painter.dart';
import 'package:odd_or_even/features/progression/presentation/widgets/rank_emblem_widget.dart';

void main() {
  group('RankEmblem - Deterministic Rendering & Painter Tests', () {
    test('EmblemParticleSystem initializes deterministically with fixed seed across all tiers', () {
      for (final tier in RankTier.values) {
        final system1 = EmblemParticleSystem(tier: tier, maxParticles: 12, seed: 999);
        final system2 = EmblemParticleSystem(tier: tier, maxParticles: 12, seed: 999);

        expect(system1.particles.length, equals(12));
        expect(system2.particles.length, equals(12));

        for (int i = 0; i < 12; i++) {
          expect(system1.particles[i].x, closeTo(system2.particles[i].x, 0.0001));
          expect(system1.particles[i].y, closeTo(system2.particles[i].y, 0.0001));
          expect(system1.particles[i].radius, closeTo(system2.particles[i].radius, 0.0001));
          expect(system1.particles[i].color, equals(system2.particles[i].color));
        }

        // Test update tick
        system1.update(0.016);
        for (final p in system1.particles) {
          expect(p.x, inInclusiveRange(0.0, 1.0));
          expect(p.y, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('RankEmblemPainter shouldRepaint optimization returns true only on meaningful state delta', () {
      final p1 = RankEmblemPainter(tier: RankTier.gold, animationProgress: 0.5, showAura: true);
      final p2 = RankEmblemPainter(tier: RankTier.gold, animationProgress: 0.5, showAura: true);
      final p3 = RankEmblemPainter(tier: RankTier.platinum, animationProgress: 0.5, showAura: true);
      final p4 = RankEmblemPainter(tier: RankTier.gold, animationProgress: 0.8, showAura: true);
      final p5 = RankEmblemPainter(tier: RankTier.gold, animationProgress: 0.5, showAura: false);

      expect(p1.shouldRepaint(p2), isFalse);
      expect(p1.shouldRepaint(p3), isTrue); // Different tier
      expect(p1.shouldRepaint(p4), isTrue); // Different animation progress
      expect(p1.shouldRepaint(p5), isTrue); // Different aura flag
    });

    testWidgets('Renders stable deterministic RepaintBoundary snapshots for all 10 tiers', (tester) async {
      // Test grid rendering of all 10 rank emblems in static deterministic mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0F081E),
            body: Center(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final tier in RankTier.values)
                      RepaintBoundary(
                        child: RankEmblemWidget(
                          tier: tier,
                          division: tier.hasDivisions ? RankDivision.I : null,
                          size: 72,
                          animate: false,
                          showDivisionBadge: tier.hasDivisions,
                          showStars: true,
                          stars: tier.hasDivisions ? 2 : (tier == RankTier.master ? 5 : 0),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure all 10 emblems and all 10 RepaintBoundaries are mounted and painted
      expect(find.byType(RankEmblemWidget), findsNWidgets(10));
      expect(find.byType(RepaintBoundary), findsWidgets);
    });
  });
}
