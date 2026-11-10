import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../domain/models/rank_tier.dart';
import '../painters/emblem_particles.dart';
import '../painters/rank_emblem_painter.dart';
import 'rank_stars_widget.dart';

/// Production-quality, resolution-independent vector rank emblem for all 10 tiers.
///
/// Features dynamic metallic/crystal/phoenix silhouettes, ambient aura glowing,
/// shimmer sweeps, and tier-specific particle systems.
///
/// Automatically respects [MediaQueryData.disableAnimations] (Reduced Motion)
/// and provides an [animate] toggle for static rendering mode.
class RankEmblemWidget extends StatefulWidget {
  final RankTier tier;
  final RankDivision? division;
  final double size;
  final bool animate;
  final bool showAura;
  final bool showDivisionBadge;
  final bool showStars;
  final int stars;
  final bool demotionShieldActive;
  final int? seed;

  const RankEmblemWidget({
    super.key,
    required this.tier,
    this.division,
    this.size = 84.0,
    this.animate = true,
    this.showAura = true,
    this.showDivisionBadge = false,
    this.showStars = false,
    this.stars = 0,
    this.demotionShieldActive = false,
    this.seed,
  });

  @override
  State<RankEmblemWidget> createState() => _RankEmblemWidgetState();
}

class _RankEmblemWidgetState extends State<RankEmblemWidget>
    with TickerProviderStateMixin {
  AnimationController? _animController;
  EmblemParticleSystem? _particleSystem;
  DateTime _lastFrameTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initAnimationIfNeeded();
  }

  @override
  void didUpdateWidget(covariant RankEmblemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tier != widget.tier && _particleSystem != null) {
      _particleSystem = EmblemParticleSystem(
        tier: widget.tier,
        maxParticles: 14,
        seed: widget.seed,
      );
    }
    if (oldWidget.animate != widget.animate) {
      if (widget.animate) {
        _initAnimationIfNeeded();
      } else {
        _disposeAnimation();
      }
    }
  }

  void _initAnimationIfNeeded() {
    if (!widget.animate) return;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addListener(_onTick)..repeat();

    _particleSystem = EmblemParticleSystem(
      tier: widget.tier,
      maxParticles: 14,
      seed: widget.seed,
    );
    _lastFrameTime = DateTime.now();
  }

  void _onTick() {
    if (!mounted || _particleSystem == null) return;
    final now = DateTime.now();
    final dt = now.difference(_lastFrameTime).inMilliseconds / 1000.0;
    _lastFrameTime = now;
    _particleSystem!.update(dt.clamp(0.001, 0.05));
    setState(() {});
  }

  void _disposeAnimation() {
    _animController?.removeListener(_onTick);
    _animController?.dispose();
    _animController = null;
    _particleSystem = null;
  }

  @override
  void dispose() {
    _disposeAnimation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bool shouldAnimate = widget.animate && !reducedMotion;

    final emblemSize = Size(widget.size, widget.size);

    Widget emblemCore = CustomPaint(
      size: emblemSize,
      painter: RankEmblemPainter(
        tier: widget.tier,
        animationProgress: shouldAnimate ? (_animController?.value ?? 0.0) : 0.0,
        particles: shouldAnimate ? _particleSystem?.particles : null,
        showAura: widget.showAura,
      ),
    );

    // Overlay Division Badge if requested
    if (widget.showDivisionBadge &&
        widget.tier.hasDivisions &&
        widget.division != null) {
      emblemCore = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          emblemCore,
          Positioned(
            bottom: -2,
            right: 0,
            child: _buildDivisionBadge(widget.division!),
          ),
        ],
      );
    }

    if (widget.showStars) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          emblemCore,
          SizedBox(height: widget.size * 0.08),
          RankStarsWidget(
            tier: widget.tier,
            stars: widget.stars,
            demotionShieldActive: widget.demotionShieldActive,
            starSize: (widget.size * 0.18).clamp(12.0, 24.0),
          ),
        ],
      );
    }

    return emblemCore;
  }

  Widget _buildDivisionBadge(RankDivision division) {
    final double badgeSize = (widget.size * 0.30).clamp(18.0, 32.0);

    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF2B194F), Color(0xFF0F081E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: GameColors.goldMetallic,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        division.label,
        style: GameTypography.caption.copyWith(
          fontSize: badgeSize * 0.42,
          fontWeight: FontWeight.w900,
          color: GameColors.goldBright,
        ),
      ),
    );
  }
}
