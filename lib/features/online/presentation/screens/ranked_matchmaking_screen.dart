import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../../progression/domain/models/rank_tier.dart';
import '../../../progression/presentation/widgets/rank_emblem_widget.dart';
import '../../../progression/presentation/widgets/rank_stars_widget.dart';
import '../controllers/ranked_matchmaking_controller.dart';

class RankedMatchmakingScreen extends ConsumerStatefulWidget {
  const RankedMatchmakingScreen({super.key});

  @override
  ConsumerState<RankedMatchmakingScreen> createState() => _RankedMatchmakingScreenState();
}

class _RankedMatchmakingScreenState extends ConsumerState<RankedMatchmakingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Auto-join queue after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(rankedMatchmakingProvider.notifier).initializeAndJoin();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(rankedMatchmakingProvider.notifier).handleAppResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _radarController.dispose();
    super.dispose();
  }

  void _handleCancel() async {
    HapticsUtil.lightTap();
    final notifier = ref.read(rankedMatchmakingProvider.notifier);
    await notifier.cancelMatchmaking();
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/');
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rankedMatchmakingProvider);
    final notifier = ref.read(rankedMatchmakingProvider.notifier);

    // Automatic route navigation on match found
    ref.listen<RankedMatchmakingUiState>(rankedMatchmakingProvider, (prev, next) {
      if ((next.isMatched || next.isActiveMatchRecovery) &&
          next.matchId != null &&
          !notifier.hasNavigated) {
        notifier.markNavigated();
        HapticsUtil.heavyImpact();
        final router = GoRouter.of(context);
        final matchId = next.matchId!;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          router.go('/ranked-play/$matchId');
        });
      }
    });

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Cancel Search',
          onPressed: state.isCancelling ? null : _handleCancel,
        ),
        title: Text(
          'ONLINE RANKED',
          style: GameTypography.headlineMedium.copyWith(
            color: GameColors.goldBright,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined, color: GameColors.goldBright),
            tooltip: 'Leaderboard',
            onPressed: () {
              HapticsUtil.lightTap();
              context.push('/ranked-leaderboard');
            },
          ),
        ],
      ),
      bottomNavigationBar: const CreatorFooter(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SingleChildScrollView(
                  child: state.isError
                      ? _buildErrorView(state)
                      : (state.isMatched || state.isActiveMatchRecovery)
                          ? _buildMatchedView(state)
                          : _buildSearchingView(state),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingView(RankedMatchmakingUiState state) {
    final rank = state.playerRank;
    final tier = rank?.tier ?? RankTier.bronze;
    final division = rank?.division ?? RankDivision.III;
    final stars = rank?.stars ?? 0;
    final mmr = rank?.mmr ?? 1000;
    final fullLabel = rank?.fullRankLabel ?? 'Bronze III';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. Player Rank Preview Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: GameColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GameColors.goldMetallic.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: GameColors.royalPurple.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              RankEmblemWidget(
                tier: tier,
                division: division,
                size: 52,
                animate: true,
                showDivisionBadge: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullLabel,
                      style: GameTypography.headlineMedium.copyWith(
                        color: GameColors.goldBright,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    RankStarsWidget(
                      tier: tier,
                      stars: stars,
                      demotionShieldActive: rank?.demotionShieldActive ?? false,
                      starSize: 15,
                      showLabel: false,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MMR: $mmr • Server Authenticated',
                      style: GameTypography.caption.copyWith(
                        color: GameColors.cyanBright,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // 2. Animated Radar Scanner
        SizedBox(
          width: 220,
          height: 220,
          child: AnimatedBuilder(
            animation: _radarController,
            builder: (context, _) {
              return CustomPaint(
                painter: _RadarPainter(_radarController.value),
                child: Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GameColors.surfaceElevated,
                      border: Border.all(color: GameColors.goldBright, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: GameColors.goldBright.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: GameColors.goldBright,
                      size: 34,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),

        // 3. Status Text & Timer
        Text(
          state.isJoining ? 'CONNECTING TO QUEUE...' : 'SEARCHING FOR OPPONENT...',
          style: GameTypography.headlineMedium.copyWith(
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatTime(state.elapsedSeconds),
          style: GameTypography.displayLarge.copyWith(
            color: GameColors.goldBright,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: GameColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GameColors.glassBorder),
          ),
          child: Text(
            'STRICT MMR BAND (±200) • 2 OVERS • 1..6',
            style: GameTypography.caption.copyWith(
              color: GameColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 36),

        // 4. Cancel Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: state.isCancelling ? null : _handleCancel,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: GameColors.wicket.withValues(alpha: 0.7),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: GameColors.surface.withValues(alpha: 0.7),
            ),
            child: state.isCancelling
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: GameColors.wicket,
                    ),
                  )
                : Text(
                    'CANCEL SEARCH',
                    style: GameTypography.headlineMedium.copyWith(
                      color: GameColors.wicket,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchedView(RankedMatchmakingUiState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GameColors.lime.withValues(alpha: 0.2),
            border: Border.all(color: GameColors.lime, width: 3),
            boxShadow: [
              BoxShadow(
                color: GameColors.lime.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: GameColors.lime,
            size: 52,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          state.isActiveMatchRecovery
              ? 'ACTIVE MATCH RECOVERED!'
              : 'OPPONENT FOUND!',
          style: GameTypography.headlineLarge.copyWith(
            color: GameColors.lime,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Entering authoritative match...',
          style: GameTypography.bodyMedium.copyWith(color: GameColors.textSecondary),
        ),
        const SizedBox(height: 20),
        const CircularProgressIndicator(color: GameColors.goldBright),
      ],
    );
  }

  Widget _buildErrorView(RankedMatchmakingUiState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GameColors.wicket.withValues(alpha: 0.2),
            border: Border.all(color: GameColors.wicket, width: 2),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: GameColors.wicket,
            size: 44,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Matchmaking Error',
          style: GameTypography.headlineLarge.copyWith(
            color: GameColors.wicket,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: GameColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GameColors.glassBorder),
          ),
          child: Text(
            state.errorMessage ?? 'An error occurred during matchmaking.',
            textAlign: TextAlign.center,
            style: GameTypography.bodyMedium.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  final router = GoRouter.maybeOf(context);
                  if (router != null) {
                    router.go('/');
                  } else if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: GameColors.glassBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Back to Home'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  ref.read(rankedMatchmakingProvider.notifier).initializeAndJoin();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.goldMetallic,
                  foregroundColor: GameColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Retry Search', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom painter rendering arcade radar concentric rings and a sweeping beam.
class _RadarPainter extends CustomPainter {
  final double animationValue;

  _RadarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..color = GameColors.royalPurple.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Concentric grid rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), ringPaint);
    }

    // Crosshairs
    final linePaint = Paint()
      ..color = GameColors.royalPurple.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), linePaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), linePaint);

    // Pulsing expander wave
    final wavePaint = Paint()
      ..color = GameColors.goldBright.withValues(alpha: (1.0 - animationValue).clamp(0.0, 0.6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, maxRadius * animationValue, wavePaint);

    // Rotating radar beam
    final beamAngle = animationValue * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          GameColors.goldBright.withValues(alpha: 0.4),
          Colors.transparent,
        ],
        transform: GradientRotation(beamAngle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
