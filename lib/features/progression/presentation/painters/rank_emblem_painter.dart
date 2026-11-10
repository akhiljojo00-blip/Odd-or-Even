import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/rank_tier.dart';
import 'emblem_particles.dart';

/// Pure vector painter rendering unique heraldic silhouettes and ambient effects
/// for all 10 rank tiers in Odd or Even.
class RankEmblemPainter extends CustomPainter {
  final RankTier tier;
  final double animationProgress; // 0.0 .. 1.0 driving shimmer and pulse
  final List<EmblemParticle>? particles;
  final bool showAura;

  RankEmblemPainter({
    required this.tier,
    this.animationProgress = 0.0,
    this.particles,
    this.showAura = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Ambient Glow Aura
    if (showAura) {
      _paintAura(canvas, center, w, h);
    }

    // 2. Shield Silhouette & Heraldic Body
    final shieldPath = _createShieldPath(w, h);
    _paintShieldBody(canvas, shieldPath, w, h);

    // 3. Shield Border & Bevel
    _paintShieldBorder(canvas, shieldPath, w, h);

    // 4. Central Insignia / Motif
    _paintCentralInsignia(canvas, center, w, h);

    // 5. Metallic / Crystal Shimmer Sweep
    if (animationProgress > 0.0) {
      _paintShimmer(canvas, shieldPath, w, h);
    }

    // 6. Tier Particles
    if (particles != null && particles!.isNotEmpty) {
      _paintParticles(canvas, w, h);
    }
  }

  // =========================================================================
  // 1. AMBIENT AURA
  // =========================================================================
  void _paintAura(Canvas canvas, Offset center, double w, double h) {
    final Color auraColor = _getAuraColor();
    final double pulse = 0.85 + 0.15 * sin(animationProgress * 2 * pi);

    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          auraColor.withValues(alpha: 0.35 * pulse),
          auraColor.withValues(alpha: 0.12 * pulse),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.58));

    canvas.drawCircle(center, w * 0.58, auraPaint);
  }

  Color _getAuraColor() {
    switch (tier) {
      case RankTier.bronze:
        return const Color(0xFFCD7F32);
      case RankTier.silver:
        return const Color(0xFFC0C0C0);
      case RankTier.gold:
        return const Color(0xFFFFD700);
      case RankTier.platinum:
        return const Color(0xFF22D3EE);
      case RankTier.diamond:
        return const Color(0xFF00F5FF);
      case RankTier.elite:
        return const Color(0xFFA855F7);
      case RankTier.proElite:
        return const Color(0xFFEF4444);
      case RankTier.legend:
        return const Color(0xFFF43F5E);
      case RankTier.master:
        return const Color(0xFFFFD700);
      case RankTier.grandMaster:
        return const Color(0xFF38BDF8);
    }
  }

  // =========================================================================
  // 2. SHIELD PATHS (10 Unique Silhouettes)
  // =========================================================================
  Path _createShieldPath(double w, double h) {
    final path = Path();

    switch (tier) {
      case RankTier.bronze:
        // Sturdy triangular arrowhead shield
        path.moveTo(w * 0.12, h * 0.18);
        path.lineTo(w * 0.88, h * 0.18);
        path.lineTo(w * 0.76, h * 0.65);
        path.lineTo(w * 0.50, h * 0.90);
        path.lineTo(w * 0.24, h * 0.65);
        path.close();
        break;

      case RankTier.silver:
        // Classic heater shield
        path.moveTo(w * 0.15, h * 0.15);
        path.quadraticBezierTo(w * 0.50, h * 0.10, w * 0.85, h * 0.15);
        path.lineTo(w * 0.85, h * 0.55);
        path.quadraticBezierTo(w * 0.82, h * 0.78, w * 0.50, h * 0.92);
        path.quadraticBezierTo(w * 0.18, h * 0.78, w * 0.15, h * 0.55);
        path.close();
        break;

      case RankTier.gold:
        // Ornate royal kite shield with crowned notch
        path.moveTo(w * 0.50, h * 0.08);
        path.lineTo(w * 0.86, h * 0.18);
        path.lineTo(w * 0.84, h * 0.58);
        path.quadraticBezierTo(w * 0.78, h * 0.82, w * 0.50, h * 0.94);
        path.quadraticBezierTo(w * 0.22, h * 0.82, w * 0.16, h * 0.58);
        path.lineTo(w * 0.14, h * 0.18);
        path.close();
        break;

      case RankTier.platinum:
        // Crystalline hexagonal shield
        path.moveTo(w * 0.50, h * 0.10);
        path.lineTo(w * 0.86, h * 0.22);
        path.lineTo(w * 0.86, h * 0.68);
        path.lineTo(w * 0.50, h * 0.92);
        path.lineTo(w * 0.14, h * 0.68);
        path.lineTo(w * 0.14, h * 0.22);
        path.close();
        break;

      case RankTier.diamond:
        // Sharp faceted gem-cut shield
        path.moveTo(w * 0.50, h * 0.08);
        path.lineTo(w * 0.82, h * 0.20);
        path.lineTo(w * 0.90, h * 0.52);
        path.lineTo(w * 0.50, h * 0.94);
        path.lineTo(w * 0.10, h * 0.52);
        path.lineTo(w * 0.18, h * 0.20);
        path.close();
        break;

      case RankTier.elite:
        // Regal gothic shield with notched horns
        path.moveTo(w * 0.50, h * 0.15);
        path.lineTo(w * 0.82, h * 0.08);
        path.lineTo(w * 0.88, h * 0.55);
        path.quadraticBezierTo(w * 0.80, h * 0.82, w * 0.50, h * 0.95);
        path.quadraticBezierTo(w * 0.20, h * 0.82, w * 0.12, h * 0.55);
        path.lineTo(w * 0.18, h * 0.08);
        path.close();
        break;

      case RankTier.proElite:
        // Spiked crimson-gold battle shield
        path.moveTo(w * 0.50, h * 0.06);
        path.lineTo(w * 0.78, h * 0.18);
        path.lineTo(w * 0.92, h * 0.38);
        path.lineTo(w * 0.84, h * 0.68);
        path.lineTo(w * 0.50, h * 0.95);
        path.lineTo(w * 0.16, h * 0.68);
        path.lineTo(w * 0.08, h * 0.38);
        path.lineTo(w * 0.22, h * 0.18);
        path.close();
        break;

      case RankTier.legend:
        // Royal shield with flanked phoenix wings
        path.moveTo(w * 0.50, h * 0.10);
        path.lineTo(w * 0.75, h * 0.15);
        path.lineTo(w * 0.95, h * 0.35); // Wing tip
        path.lineTo(w * 0.80, h * 0.52);
        path.lineTo(w * 0.88, h * 0.65); // Second wing tip
        path.lineTo(w * 0.50, h * 0.94);
        path.lineTo(w * 0.12, h * 0.65);
        path.lineTo(w * 0.20, h * 0.52);
        path.lineTo(w * 0.05, h * 0.35);
        path.lineTo(w * 0.25, h * 0.15);
        path.close();
        break;

      case RankTier.master:
        // Octagonal royal starburst medallion
        final r = w * 0.42;
        final c = Offset(w * 0.50, h * 0.50);
        for (int i = 0; i < 8; i++) {
          final a = (i * pi / 4) - (pi / 8);
          final p = c + Offset(cos(a) * r, sin(a) * r);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        break;

      case RankTier.grandMaster:
        // Mythic triple imperial winged crest
        path.moveTo(w * 0.50, h * 0.05); // Central apex crown
        path.lineTo(w * 0.70, h * 0.15);
        path.lineTo(w * 0.82, h * 0.08); // Right crown point
        path.lineTo(w * 0.96, h * 0.32); // Wing flare
        path.lineTo(w * 0.80, h * 0.58);
        path.lineTo(w * 0.50, h * 0.96); // Bottom sacred tip
        path.lineTo(w * 0.20, h * 0.58);
        path.lineTo(w * 0.04, h * 0.32); // Left wing flare
        path.lineTo(w * 0.18, h * 0.08); // Left crown point
        path.lineTo(w * 0.30, h * 0.15);
        path.close();
        break;
    }

    return path;
  }

  // =========================================================================
  // 3. SHIELD BODY FILL
  // =========================================================================
  void _paintShieldBody(Canvas canvas, Path path, double w, double h) {
    final gradient = _getShieldGradient(w, h);
    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Inner shadow for depth
    final innerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.45),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), innerPaint);
    canvas.restore();
  }

  Shader _getShieldGradient(double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    switch (tier) {
      case RankTier.bronze:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCD7F32), Color(0xFF8B4513), Color(0xFF5C2C10)],
        ).createShader(rect);

      case RankTier.silver:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F5F9), Color(0xFFCBD5E1), Color(0xFF64748B)],
        ).createShader(rect);

      case RankTier.gold:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFFD700), Color(0xFFB45309)],
        ).createShader(rect);

      case RankTier.platinum:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0369A1)],
        ).createShader(rect);

      case RankTier.diamond:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDF4), Color(0xFF00F5FF), Color(0xFF0284C7), Color(0xFF0C4A6E)],
        ).createShader(rect);

      case RankTier.elite:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAF5FF), Color(0xFFA855F7), Color(0xFF6B21A8)],
        ).createShader(rect);

      case RankTier.proElite:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFEF2F2), Color(0xFFEF4444), Color(0xFF7F1D1D)],
        ).createShader(rect);

      case RankTier.legend:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBBF24), Color(0xFFF43F5E), Color(0xFF581C87)],
        ).createShader(rect);

      case RankTier.master:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFFD700), Color(0xFF4338CA)],
        ).createShader(rect);

      case RankTier.grandMaster:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFD700), Color(0xFF0284C7), Color(0xFF1E1B4B)],
        ).createShader(rect);
    }
  }

  // =========================================================================
  // 4. SHIELD BORDER & METALLIC BEVEL
  // =========================================================================
  void _paintShieldBorder(Canvas canvas, Path path, double w, double h) {
    final borderColors = _getBorderColors();
    final strokePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: borderColors,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, w * 0.04)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);
  }

  List<Color> _getBorderColors() {
    switch (tier) {
      case RankTier.bronze:
        return [const Color(0xFFFFA07A), const Color(0xFFCD7F32), const Color(0xFF8B4513)];
      case RankTier.silver:
        return [Colors.white, const Color(0xFFE2E8F0), const Color(0xFF94A3B8)];
      case RankTier.gold:
        return [Colors.white, const Color(0xFFFFD700), const Color(0xFFD97706)];
      case RankTier.platinum:
        return [Colors.white, const Color(0xFFA5F3FC), const Color(0xFF0284C7)];
      case RankTier.diamond:
        return [Colors.white, const Color(0xFF38BDF8), const Color(0xFF0EA5E9)];
      case RankTier.elite:
        return [Colors.white, const Color(0xFFD8B4FE), const Color(0xFF7E22CE)];
      case RankTier.proElite:
        return [const Color(0xFFFDE68A), const Color(0xFFEF4444), const Color(0xFF991B1B)];
      case RankTier.legend:
        return [const Color(0xFFFDE68A), const Color(0xFFF43F5E), const Color(0xFF7C3AED)];
      case RankTier.master:
        return [Colors.white, const Color(0xFFFFD700), const Color(0xFF6366F1)];
      case RankTier.grandMaster:
        return [Colors.white, const Color(0xFFFFD700), const Color(0xFF38BDF8), Colors.white];
    }
  }

  // =========================================================================
  // 5. CENTRAL INSIGNIA / MOTIF
  // =========================================================================
  void _paintCentralInsignia(Canvas canvas, Offset center, double w, double h) {
    final iconPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = _getAuraColor().withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, w * 0.025);

    switch (tier) {
      case RankTier.bronze:
        // Embossed cricket ball circle with seam
        final r = w * 0.18;
        canvas.drawCircle(center, r, iconPaint);
        // Seam curve
        final seamPath = Path()
          ..moveTo(center.dx - r * 0.7, center.dy - r * 0.5)
          ..quadraticBezierTo(center.dx, center.dy, center.dx + r * 0.7, center.dy + r * 0.5);
        canvas.drawPath(seamPath, accentPaint);
        break;

      case RankTier.silver:
        // Diagonal cricket bat
        final batPath = Path()
          ..moveTo(center.dx - w * 0.12, center.dy + h * 0.16)
          ..lineTo(center.dx + w * 0.12, center.dy - h * 0.16)
          ..lineTo(center.dx + w * 0.16, center.dy - h * 0.12)
          ..lineTo(center.dx - w * 0.08, center.dy + h * 0.20)
          ..close();
        canvas.drawPath(batPath, iconPaint);
        break;

      case RankTier.gold:
        // Crowned cricket ball
        final r = w * 0.14;
        canvas.drawCircle(Offset(center.dx, center.dy + h * 0.06), r, iconPaint);
        // Mini crown above ball
        final crownPath = Path()
          ..moveTo(center.dx - w * 0.12, center.dy - h * 0.04)
          ..lineTo(center.dx - w * 0.14, center.dy - h * 0.15)
          ..lineTo(center.dx - w * 0.06, center.dy - h * 0.09)
          ..lineTo(center.dx, center.dy - h * 0.18)
          ..lineTo(center.dx + w * 0.06, center.dy - h * 0.09)
          ..lineTo(center.dx + w * 0.14, center.dy - h * 0.15)
          ..lineTo(center.dx + w * 0.12, center.dy - h * 0.04)
          ..close();
        canvas.drawPath(crownPath, iconPaint);
        break;

      case RankTier.platinum:
        // Crossed dual bats
        _drawCrossedLines(canvas, center, w * 0.28, w * 0.035, iconPaint);
        break;

      case RankTier.diamond:
        // Multi-faceted crystal diamond
        final diamondPath = Path()
          ..moveTo(center.dx, center.dy - h * 0.20)
          ..lineTo(center.dx + w * 0.18, center.dy)
          ..lineTo(center.dx, center.dy + h * 0.20)
          ..lineTo(center.dx - w * 0.18, center.dy)
          ..close();
        canvas.drawPath(diamondPath, iconPaint);
        // Inner facet cross
        canvas.drawLine(
          Offset(center.dx - w * 0.18, center.dy),
          Offset(center.dx + w * 0.18, center.dy),
          accentPaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - h * 0.20),
          Offset(center.dx, center.dy + h * 0.20),
          accentPaint,
        );
        break;

      case RankTier.elite:
        // Glowing central rune crystal
        final runePath = Path()
          ..moveTo(center.dx, center.dy - h * 0.22)
          ..lineTo(center.dx + w * 0.15, center.dy - h * 0.05)
          ..lineTo(center.dx + w * 0.12, center.dy + h * 0.18)
          ..lineTo(center.dx, center.dy + h * 0.24)
          ..lineTo(center.dx - w * 0.12, center.dy + h * 0.18)
          ..lineTo(center.dx - w * 0.15, center.dy - h * 0.05)
          ..close();
        canvas.drawPath(runePath, iconPaint);
        break;

      case RankTier.proElite:
        // 5-Point radiant star
        _drawStar(canvas, center, 5, w * 0.20, w * 0.09, iconPaint);
        break;

      case RankTier.legend:
        // Phoenix flame bird emblem
        final flamePath = Path()
          ..moveTo(center.dx, center.dy - h * 0.22)
          ..quadraticBezierTo(center.dx + w * 0.16, center.dy - h * 0.08, center.dx + w * 0.12, center.dy + h * 0.12)
          ..quadraticBezierTo(center.dx, center.dy + h * 0.22, center.dx, center.dy + h * 0.22)
          ..quadraticBezierTo(center.dx, center.dy + h * 0.22, center.dx - w * 0.12, center.dy + h * 0.12)
          ..quadraticBezierTo(center.dx - w * 0.16, center.dy - h * 0.08, center.dx, center.dy - h * 0.22);
        canvas.drawPath(flamePath, iconPaint);
        break;

      case RankTier.master:
        // 5-Jewel Royal Crown
        final masterCrown = Path()
          ..moveTo(center.dx - w * 0.18, center.dy + h * 0.12)
          ..lineTo(center.dx - w * 0.22, center.dy - h * 0.10)
          ..lineTo(center.dx - w * 0.11, center.dy - h * 0.02)
          ..lineTo(center.dx, center.dy - h * 0.16)
          ..lineTo(center.dx + w * 0.11, center.dy - h * 0.02)
          ..lineTo(center.dx + w * 0.22, center.dy - h * 0.10)
          ..lineTo(center.dx + w * 0.18, center.dy + h * 0.12)
          ..close();
        canvas.drawPath(masterCrown, iconPaint);
        break;

      case RankTier.grandMaster:
        // Triple imperial crown with winged radiant star
        _drawStar(canvas, Offset(center.dx, center.dy + h * 0.04), 8, w * 0.18, w * 0.08, iconPaint);
        // Apex jewel
        canvas.drawCircle(Offset(center.dx, center.dy - h * 0.14), w * 0.04, iconPaint);
        break;
    }
  }

  void _drawCrossedLines(Canvas canvas, Offset center, double length, double width, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: length, height: width), const Radius.circular(2)),
      paint,
    );
    canvas.rotate(pi / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: length, height: width), const Radius.circular(2)),
      paint,
    );
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset center, int points, double outerR, double innerR, Paint paint) {
    final path = Path();
    final double angleStep = pi / points;
    double currentAngle = -pi / 2;

    for (int i = 0; i < points * 2; i++) {
      final r = (i % 2 == 0) ? outerR : innerR;
      final p = center + Offset(cos(currentAngle) * r, sin(currentAngle) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      currentAngle += angleStep;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // =========================================================================
  // 6. METALLIC / CRYSTAL SHIMMER SWEEP
  // =========================================================================
  void _paintShimmer(Canvas canvas, Path path, double w, double h) {
    final shimmerX = -w + (w * 3) * animationProgress;
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(shimmerX, 0, w * 0.6, h))
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(Rect.fromLTWH(shimmerX, 0, w * 0.6, h), shimmerPaint);
    canvas.restore();
  }

  // =========================================================================
  // 7. PARTICLES
  // =========================================================================
  void _paintParticles(Canvas canvas, double w, double h) {
    for (final p in particles!) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(p.x * w, p.y * h), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RankEmblemPainter oldDelegate) {
    return oldDelegate.tier != tier ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.particles != particles ||
        oldDelegate.showAura != showAura;
  }
}
