import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
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

    await repo.ensureAuthenticatedUser();
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
      body: SafeArea(
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
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing Rings
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return Container(
                            width: 140 + (_animController.value * 60),
                            height: 140 + (_animController.value * 60),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: GameColors.lime.withOpacity(1.0 - _animController.value),
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
                          color: GameColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: GameColors.lime, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: GameColors.lime.withOpacity(0.3),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.bolt_rounded, size: 56, color: GameColors.lime),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              Text(
                'FINDING OPPONENT',
                textAlign: TextAlign.center,
                style: GameTypography.headlineMedium.copyWith(
                  letterSpacing: 2.0,
                  color: GameColors.lime,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Searching globally for a 1v1 challenger...',
                textAlign: TextAlign.center,
                style: GameTypography.bodyMedium,
              ),
              const SizedBox(height: 16),

              Text(
                '${_secondsElapsed ~/ 60}:${(_secondsElapsed % 60).toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: GameTypography.displayMedium.copyWith(
                  color: GameColors.gold,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),

              // Cancel search
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: _cancelQueue,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GameColors.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    'CANCEL SEARCH',
                    style: GameTypography.headlineMedium.copyWith(
                      fontSize: 15,
                      color: GameColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
