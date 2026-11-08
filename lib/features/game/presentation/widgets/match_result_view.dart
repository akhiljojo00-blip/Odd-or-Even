import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../domain/models/game_enums.dart';
import '../../domain/models/game_match_state.dart';

/// Reusable Match Result Presentation Component for Pass & Play, VS Computer, and Online.
///
/// Supports VICTORY, DEFEAT, and DRAW/TIE with cinematic animations, celebration particles,
/// final scoreboard breakdown, and rematch/home action triggers.
class MatchResultView extends StatefulWidget {
  final GameMatchState match;
  final String? currentUserId; // Null in Pass & Play; 'human' in VS Computer; userId in Online
  final VoidCallback onRematch;
  final VoidCallback onHome;
  final bool isRematchSubmitting;
  final String? rematchStatusText;

  const MatchResultView({
    super.key,
    required this.match,
    this.currentUserId,
    required this.onRematch,
    required this.onHome,
    this.isRematchSubmitting = false,
    this.rematchStatusText,
  });

  @override
  State<MatchResultView> createState() => _MatchResultViewState();
}

class _MatchResultViewState extends State<MatchResultView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _trophyBounceAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    _trophyBounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final isTie = match.resultType == MatchResultType.tie;
    final isSeriesFinished = match.phase == MatchPhase.seriesFinished;

    final winner = match.winnerId != null ? match.getPlayerById(match.winnerId!) : null;

    // Determine result perspective:
    // If currentUserId is provided, determine if current user won
    // Otherwise (Pass & Play), it is always a celebration of the match winner
    final bool isUserWinner;
    if (widget.currentUserId != null) {
      isUserWinner = match.winnerId == widget.currentUserId;
    } else {
      isUserWinner = winner != null; // In Pass & Play, celebrate winner
    }

    final String titleText;
    final String subtitleText;
    final Color accentColor;
    final Gradient bannerGradient;

    if (isSeriesFinished) {
      titleText = 'SERIES CHAMPION!';
      subtitleText = '${match.seriesWinner?.name ?? "Winner"} conquered the series (${match.config.seriesTargetPoints} wins target hit)!';
      accentColor = GameColors.goldBright;
      bannerGradient = GameColors.goldGradient;
    } else if (isTie) {
      titleText = 'MATCH TIED!';
      subtitleText = 'Both players finished on exactly ${match.firstInningsRuns} runs! A rare duel draw.';
      accentColor = GameColors.amber;
      bannerGradient = const LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)]);
    } else if (isUserWinner) {
      titleText = widget.currentUserId != null ? 'VICTORY!' : '${winner?.name.toUpperCase()} WINS!';
      subtitleText = match.resultType?.description ?? 'Match Won';
      accentColor = GameColors.goldBright;
      bannerGradient = GameColors.goldGradient;
    } else {
      titleText = 'DEFEAT';
      subtitleText = '${winner?.name ?? "Opponent"} won this match. Ready to settle the score?';
      accentColor = const Color(0xFF94A3B8);
      bannerGradient = const LinearGradient(colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)]);
    }

    return Stack(
      children: [
        // 1. Victory Celebration Confetti Particles (Only on victory!)
        if (isUserWinner && !isTie)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(progress: _animController.value),
                  );
                },
              ),
            ),
          ),

        // 2. Main Content Card
        Positioned.fill(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      const SizedBox(height: 8),

                      // Trophy / Medal / Handshake Emblem
                      Center(
                        child: AnimatedBuilder(
                          animation: _trophyBounceAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 0.8 + (0.2 * _trophyBounceAnimation.value),
                              child: child,
                            );
                          },
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  accentColor.withValues(alpha: 0.35),
                                  accentColor.withValues(alpha: 0.08),
                                ],
                              ),
                              border: Border.all(color: accentColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.5),
                                  blurRadius: 32,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              isSeriesFinished
                                  ? Icons.military_tech_rounded
                                  : (isTie
                                      ? Icons.handshake_rounded
                                      : (isUserWinner ? Icons.emoji_events_rounded : Icons.shield_outlined)),
                              size: 56,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Animated Title
                      ShaderMask(
                        shaderCallback: (bounds) => bannerGradient.createShader(bounds),
                        child: Text(
                          titleText,
                          textAlign: TextAlign.center,
                          style: GameTypography.displayLarge.copyWith(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: accentColor.withValues(alpha: 0.6),
                                blurRadius: 18,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitleText,
                        textAlign: TextAlign.center,
                        style: GameTypography.bodyMedium.copyWith(
                          color: GameColors.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Match Scoreboard Summary Card
                      _buildScoreboardSummary(match),
                      const SizedBox(height: 24),

                      // Rematch Button
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: widget.isRematchSubmitting
                              ? null
                              : () {
                                  HapticsUtil.mediumTap();
                                  widget.onRematch();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF84CC16), Color(0xFF10B981)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                              boxShadow: [
                                BoxShadow(
                                  color: GameColors.lime.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: widget.isRematchSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.replay_rounded, color: Colors.white, size: 22),
                                        const SizedBox(width: 8),
                                        Text(
                                          'PLAY AGAIN',
                                          style: GameTypography.headlineMedium.copyWith(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.rematchStatusText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.rematchStatusText!,
                          textAlign: TextAlign.center,
                          style: GameTypography.caption.copyWith(color: GameColors.cyanBright, fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Home Button
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticsUtil.lightTap();
                            widget.onHome();
                          },
                          icon: const Icon(Icons.home_rounded, color: GameColors.textSecondary, size: 20),
                          label: Text(
                            'BACK TO MAIN MENU',
                            style: GameTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              color: GameColors.textSecondary,
                              letterSpacing: 0.5,
                              fontSize: 14,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: GameColors.glassBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: GameColors.surface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
  }

  Widget _buildScoreboardSummary(GameMatchState match) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: GameColors.surfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GameColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInningsStat(
                  label: '1ST INNINGS',
                  runs: match.firstInningsRuns,
                  balls: match.legalBallsBowled,
                  isBattingFirst: true,
                ),
              ),
              Container(width: 1.2, height: 48, color: GameColors.glassBorder),
              Expanded(
                child: _buildInningsStat(
                  label: '2ND INNINGS',
                  runs: match.currentInningsRuns,
                  balls: match.legalBallsBowled,
                  isBattingFirst: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: GameColors.glassBorder, height: 1),
          const SizedBox(height: 12),

          // Series Score
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'SERIES STANDINGS',
                style: GameTypography.caption.copyWith(
                  color: GameColors.textMuted,
                  letterSpacing: 1.0,
                  fontSize: 10.5,
                ),
              ),
              Text(
                '${match.player1.name}: ${match.player1.seriesScore}  |  ${match.player2.name}: ${match.player2.seriesScore}',
                style: GameTypography.headlineMedium.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: GameColors.goldBright,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInningsStat({
    required String label,
    required int runs,
    required int balls,
    required bool isBattingFirst,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GameTypography.caption.copyWith(
            color: GameColors.textMuted,
            fontSize: 10.5,
            letterSpacing: 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$runs',
          style: GameTypography.scoreNumber.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          'RUNS',
          style: GameTypography.caption.copyWith(
            color: GameColors.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// High-performance celebratory confetti particle canvas painter.
class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final List<_ConfettiParticle> _particles = List.generate(
    48,
    (i) => _ConfettiParticle(
      xSeed: (i * 37 % 100) / 100.0,
      speed: 0.6 + ((i * 13 % 10) / 10.0) * 0.8,
      size: 4.0 + (i % 6),
      color: _confettiColors[i % _confettiColors.length],
      shape: _ConfettiShape.values[i % _ConfettiShape.values.length],
      sway: ((i * 17 % 20) - 10) / 10.0,
    ),
  );

  static const List<Color> _confettiColors = [
    Color(0xFFFACC15), // Gold
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFFA855F7), // Purple
    Color(0xFFF43F5E), // Rose
  ];

  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final y = (p.speed * progress * size.height * 1.2) % size.height;
      final x = (p.xSeed * size.width) + (math.sin(progress * math.pi * 4 + p.xSeed) * 25 * p.sway);
      final paint = Paint()
        ..color = p.color.withValues(alpha: math.max(0.0, 1.0 - (y / size.height) * 0.4))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 3 * p.sway);

      if (p.shape == _ConfettiShape.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else if (p.shape == _ConfettiShape.rectangle) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.8, height: p.size * 0.8),
          paint,
        );
      } else {
        // Star particle
        final path = Path();
        for (int i = 0; i < 5; i++) {
          final a1 = (i * 72 - 18) * math.pi / 180;
          final a2 = (i * 72 + 18) * math.pi / 180;
          final r1 = p.size;
          final r2 = p.size * 0.45;
          if (i == 0) {
            path.moveTo(math.cos(a1) * r1, math.sin(a1) * r1);
          } else {
            path.lineTo(math.cos(a1) * r1, math.sin(a1) * r1);
          }
          path.lineTo(math.cos(a2) * r2, math.sin(a2) * r2);
        }
        path.close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

enum _ConfettiShape { circle, rectangle, star }

class _ConfettiParticle {
  final double xSeed;
  final double speed;
  final double size;
  final Color color;
  final _ConfettiShape shape;
  final double sway;

  const _ConfettiParticle({
    required this.xSeed,
    required this.speed,
    required this.size,
    required this.color,
    required this.shape,
    required this.sway,
  });
}
