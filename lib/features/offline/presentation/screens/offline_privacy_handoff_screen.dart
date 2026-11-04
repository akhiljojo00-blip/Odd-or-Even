import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';

class OfflinePrivacyHandoffScreen extends StatelessWidget {
  final String nextPlayerName;
  final VoidCallback onReady;

  const OfflinePrivacyHandoffScreen({
    super.key,
    required this.nextPlayerName,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: GameColors.lime.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: GameColors.lime, width: 2),
                ),
                child: const Icon(
                  Icons.phonelink_ring_rounded,
                  size: 48,
                  color: GameColors.lime,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'PASS DEVICE TO',
                textAlign: TextAlign.center,
                style: GameTypography.caption.copyWith(
                  letterSpacing: 2.0,
                  fontSize: 14,
                  color: GameColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nextPlayerName.toUpperCase(),
                textAlign: TextAlign.center,
                style: GameTypography.displayLarge.copyWith(
                  color: GameColors.lime,
                  fontSize: 34,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GameColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GameColors.glassBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: GameColors.amber, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Secret submission locked. Opponent\'s choice is hidden to ensure fair gameplay.',
                        style: GameTypography.bodyMedium.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticsUtil.mediumTap();
                    onReady();
                  },
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(
                    'I AM $nextPlayerName (UNLOCK)',
                    style: GameTypography.headlineMedium.copyWith(
                      fontSize: 16,
                      color: GameColors.background,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.lime,
                    foregroundColor: GameColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
