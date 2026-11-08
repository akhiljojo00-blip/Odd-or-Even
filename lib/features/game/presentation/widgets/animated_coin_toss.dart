import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../domain/models/game_enums.dart';

/// Interactive 3D Perspective Animated Coin Toss widget for cricket duel.
///
/// Flips a high-fidelity arcade metallic coin with 3D perspective rotation,
/// settling authoritatively on the determined Odd or Even outcome.
class AnimatedCoinToss extends StatefulWidget {
  final Parity? outcome; // If non-null, coin settles on this outcome
  final bool isFlipping;
  final VoidCallback? onFlipComplete;
  final double size;

  const AnimatedCoinToss({
    super.key,
    this.outcome,
    this.isFlipping = false,
    this.onFlipComplete,
    this.size = 110,
  });

  @override
  State<AnimatedCoinToss> createState() => _AnimatedCoinTossState();
}

class _AnimatedCoinTossState extends State<AnimatedCoinToss>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFlipComplete?.call();
      }
    });

    if (widget.isFlipping) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCoinToss oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipping && !oldWidget.isFlipping) {
      _controller.forward(from: 0.0);
    } else if (!widget.isFlipping && oldWidget.isFlipping) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Number of half-rotations (e.g. 6 full flips = 12 half flips)
        final outcome = widget.outcome;
        final targetHalfTurns = (outcome == Parity.even) ? 10.0 : 9.0;
        final currentTurns = _flipAnimation.value * targetHalfTurns;
        final angle = currentTurns * math.pi;

        // Front face is visible when cos(angle) > 0
        final isFront = math.cos(angle) >= 0;

        return Center(
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002) // Perspective factor
              ..rotateX(angle),
            alignment: Alignment.center,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFFDE68A),
                    Color(0xFFF59E0B),
                    Color(0xFFB45309),
                  ],
                  stops: [0.3, 0.75, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 3.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: GameColors.goldBright.withValues(
                      alpha: 0.35 * _glowAnimation.value,
                    ),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer coin rim grooves
                  Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD97706),
                        width: 1.8,
                      ),
                    ),
                  ),

                  // Coin Content (flips perspective when on back)
                  Transform(
                    transform: isFront
                        ? Matrix4.identity()
                        : (Matrix4.identity()..rotateX(math.pi)),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isFront ? Icons.monetization_on_rounded : Icons.sports_cricket_rounded,
                          size: widget.size * 0.32,
                          color: const Color(0xFF78350F),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isFront
                              ? (outcome == Parity.even ? 'EVEN' : 'ODD')
                              : (outcome == Parity.even ? 'ODD' : 'EVEN'),
                          style: GameTypography.headlineMedium.copyWith(
                            fontSize: widget.size * 0.18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: const Color(0xFF78350F),
                            shadows: const [
                              Shadow(
                                color: Color(0xFFFEF3C7),
                                offset: Offset(0, 1),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
