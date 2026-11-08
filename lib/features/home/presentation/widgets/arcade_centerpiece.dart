import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';

class ArcadeCenterpiece extends StatefulWidget {
  final double size;

  const ArcadeCenterpiece({
    super.key,
    this.size = 180,
  });

  @override
  State<ArcadeCenterpiece> createState() => _ArcadeCenterpieceState();
}

class _ArcadeCenterpieceState extends State<ArcadeCenterpiece>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        final pulse = math.sin(val * 2 * math.pi) * 0.05 + 1.0;
        final floatOffset = math.sin(val * 2 * math.pi) * 4.0;

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Transform.scale(
            scale: pulse,
            child: SizedBox(
              width: s,
              height: s,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer radiant glow ring
                  Container(
                    width: s * 0.94,
                    height: s * 0.94,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          GameColors.violetNeon.withValues(alpha: 0.35),
                          GameColors.cyan.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.4, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Rotating neon energy dashed ring
                  Transform.rotate(
                    angle: val * 2 * math.pi,
                    child: CustomPaint(
                      size: Size(s * 0.88, s * 0.88),
                      painter: _ArcadeRingPainter(),
                    ),
                  ),

                  // Beveled stadium crest
                  Container(
                    width: s * 0.76,
                    height: s * 0.76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF381A6B),
                          Color(0xFF220F45),
                          Color(0xFF130728),
                        ],
                        stops: [0.3, 0.7, 1.0],
                      ),
                      border: Border.all(
                        color: GameColors.goldBright,
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: GameColors.gold.withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: GameColors.violetNeon.withValues(alpha: 0.3),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Crossed bats in background
                        Transform.rotate(
                          angle: -math.pi / 4,
                          child: Icon(
                            Icons.sports_cricket,
                            size: s * 0.42,
                            color: GameColors.violetNeon.withValues(alpha: 0.35),
                          ),
                        ),
                        Transform.rotate(
                          angle: math.pi / 4,
                          child: Icon(
                            Icons.sports_cricket,
                            size: s * 0.42,
                            color: GameColors.cyan.withValues(alpha: 0.35),
                          ),
                        ),

                        // Glowing 3D Cricket Ball Centerpiece
                        Container(
                          width: s * 0.36,
                          height: s * 0.36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-0.35, -0.35),
                              colors: [
                                Color(0xFFFF6B6B),
                                Color(0xFFDC2626),
                                Color(0xFF7F1D1D),
                              ],
                              stops: [0.0, 0.6, 1.0],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Ball seam stitching
                              CustomPaint(
                                size: Size(s * 0.36, s * 0.36),
                                painter: _BallSeamPainter(),
                              ),
                              // Number showdown 1 vs 2 badge
                              Text(
                                'VS',
                                style: GameTypography.headlineMedium.copyWith(
                                  fontSize: s * 0.12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom golden ribbon badge: "DUEL OF NUMBERS"
                  Positioned(
                    bottom: s * 0.04,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: s * 0.08,
                        vertical: s * 0.025,
                      ),
                      decoration: BoxDecoration(
                        gradient: GameColors.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: s * 0.07, color: const Color(0xFF78350F)),
                          SizedBox(width: s * 0.02),
                          Text(
                            'DUEL OF NUMBERS',
                            style: GameTypography.caption.copyWith(
                              fontSize: s * 0.062,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: const Color(0xFF78350F),
                            ),
                          ),
                          SizedBox(width: s * 0.02),
                          Icon(Icons.star_rounded, size: s * 0.07, color: const Color(0xFF78350F)),
                        ],
                      ),
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

class _ArcadeRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint1 = Paint()
      ..color = GameColors.violetNeon.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final paint2 = Paint()
      ..color = GameColors.cyanBright.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const segments = 8;
    const arcLen = (2 * math.pi) / segments;
    for (int i = 0; i < segments; i++) {
      final startAngle = i * arcLen;
      final sweepAngle = arcLen * 0.6;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        i % 2 == 0 ? paint1 : paint2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BallSeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Seam line down the center
    final path = Path();
    path.moveTo(size.width * 0.5, 2);
    path.quadraticBezierTo(
      size.width * 0.45,
      size.height * 0.5,
      size.width * 0.5,
      size.height - 2,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
