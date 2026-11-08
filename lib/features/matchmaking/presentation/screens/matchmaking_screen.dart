import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../../game/domain/models/match_config.dart';
import '../../../online/data/supabase_match_repository.dart';

class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _searchTimer;
  Timer? _pollTimer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _searchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });

    _joinQueue();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _pollTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _joinQueue() async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    if (!repo.isConfigured) {
      // Unconfigured or demo fallback: simulate quick pairing after 3 seconds
      _pollTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _searchTimer?.cancel();
        context.go('/offline-setup');
      });
      return;
    }

    final userId = await repo.ensureAuthenticatedUser();
    if (userId == null) {
      if (!mounted) return;
      final authErr = repo.lastAuthError ?? 'Authentication failed. Please verify Supabase configuration.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authErr),
          backgroundColor: GameColors.wicket,
          duration: const Duration(seconds: 5),
        ),
      );
      _cancelQueue();
      return;
    }

    final res = await repo.joinMatchmaking(const MatchConfig());

    if (!mounted) return;
    if (res != null && res['status'] == 'matched') {
      final matchId = res['match_id'] as String;
      _onMatched(matchId);
    } else {
      // Poll every 2 seconds
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollQueue());
    }
  }

  Future<void> _pollQueue() async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    final res = await repo.pollMatchmaking();
    if (!mounted) return;

    if (res != null && res['status'] == 'matched') {
      final matchId = res['match_id'] as String;
      _onMatched(matchId);
    }
  }

  void _onMatched(String matchId) {
    _searchTimer?.cancel();
    _pollTimer?.cancel();
    HapticsUtil.heavyImpact();
    context.go('/online-play/$matchId');
  }

  Future<void> _cancelQueue() async {
    _searchTimer?.cancel();
    _pollTimer?.cancel();
    final repo = ref.read(supabaseMatchRepositoryProvider);
    if (repo.isConfigured) {
      await repo.cancelMatchmaking();
    }
    if (mounted) {
      try {
        context.go('/');
      } catch (_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _cancelQueue,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),

                    // Animated Radar Scanning Circle
                    Center(
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Radiant Glow
                            AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) {
                                return Container(
                                  width: 130 + (_animController.value * 80),
                                  height: 130 + (_animController.value * 80),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: GameColors.goldBright.withValues(alpha: (1.0 - _animController.value).clamp(0.0, 1.0)),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                            AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) {
                                return Container(
                                  width: 100 + (_animController.value * 60),
                                  height: 100 + (_animController.value * 60),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: GameColors.electricViolet.withValues(alpha: (1.0 - _animController.value).clamp(0.0, 1.0)),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: const RadialGradient(
                                  colors: [Color(0xFF381A6B), Color(0xFF1E0E3D)],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: GameColors.goldBright, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: GameColors.gold.withValues(alpha: 0.45),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.bolt_rounded, size: 60, color: GameColors.goldBright),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    ShaderMask(
                      shaderCallback: (bounds) => GameColors.goldGradient.createShader(bounds),
                      child: Text(
                        'FINDING OPPONENT',
                        textAlign: TextAlign.center,
                        style: GameTypography.headlineMedium.copyWith(
                          letterSpacing: 2.2,
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Searching globally for a 1v1 challenger...',
                      textAlign: TextAlign.center,
                      style: GameTypography.bodyMedium.copyWith(color: GameColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      '${_secondsElapsed ~/ 60}:${(_secondsElapsed % 60).toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: GameTypography.displayMedium.copyWith(
                        color: GameColors.goldBright,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),

                    // Cancel search
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _cancelQueue,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: GameColors.glassBorder, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text(
                          'CANCEL SEARCH',
                          style: GameTypography.headlineMedium.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: GameColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const CreatorFooter(),
    );
  }
}
