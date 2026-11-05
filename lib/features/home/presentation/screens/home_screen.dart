import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Settings & History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: GameColors.lime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GameColors.lime.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, color: GameColors.lime, size: 8),
                        const SizedBox(width: 6),
                        Text(
                          'READY TO PLAY',
                          style: GameTypography.caption.copyWith(
                            color: GameColors.lime,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.person_outline_rounded, color: GameColors.textSecondary),
                        onPressed: () {
                          HapticsUtil.lightTap();
                          context.push('/profile');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.history_rounded, color: GameColors.textSecondary),
                        onPressed: () {
                          HapticsUtil.lightTap();
                          context.push('/history');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: GameColors.textSecondary),
                        onPressed: () {
                          HapticsUtil.lightTap();
                          context.push('/settings');
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Title Branding
              Text(
                'ODD OR EVEN',
                textAlign: TextAlign.center,
                style: GameTypography.displayLarge.copyWith(
                  letterSpacing: 2.5,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CLASSIC FINGER CRICKET DUEL',
                textAlign: TextAlign.center,
                style: GameTypography.caption.copyWith(
                  letterSpacing: 1.5,
                  color: GameColors.lime,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),

              // Game Mode Cards
              _buildGameModeCard(
                context: context,
                title: 'PASS & PLAY',
                subtitle: 'Local 2-player on one device with privacy screen',
                icon: Icons.phone_android_rounded,
                accentColor: GameColors.lime,
                badgeText: 'OFFLINE READY',
                onTap: () {
                  HapticsUtil.mediumTap();
                  context.push('/offline-setup');
                },
              ),
              const SizedBox(height: 16),

              _buildGameModeCard(
                context: context,
                title: 'ONLINE ROOMS',
                subtitle: 'Host or join private matches with 6-character room codes',
                icon: Icons.meeting_room_rounded,
                accentColor: GameColors.player1,
                badgeText: 'MULTIPLAYER',
                onTap: () {
                  HapticsUtil.mediumTap();
                  context.push('/online-lobby');
                },
              ),
              const SizedBox(height: 16),

              _buildGameModeCard(
                context: context,
                title: 'QUICK MATCH',
                subtitle: 'Instant 1v1 matchmaking with online players',
                icon: Icons.bolt_rounded,
                accentColor: GameColors.gold,
                badgeText: 'FAST PAIRING',
                onTap: () {
                  HapticsUtil.mediumTap();
                  context.push('/matchmaking');
                },
              ),
              const Spacer(),

              // Rules Helper
              Center(
                child: TextButton.icon(
                  onPressed: () => _showRulesDialog(context),
                  icon: const Icon(Icons.help_outline_rounded, size: 18, color: GameColors.textMuted),
                  label: Text(
                    'How to Play Odd or Even',
                    style: GameTypography.caption.copyWith(color: GameColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const CreatorFooter(padding: EdgeInsets.only(top: 4, bottom: 2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: GameColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GameColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GameTypography.headlineMedium.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: GameTypography.caption.copyWith(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GameTypography.caption.copyWith(
                      color: GameColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: GameColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('HOW TO PLAY', style: GameTypography.headlineMedium.copyWith(color: GameColors.lime)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRuleItem('1. Number Selection', 'Pick numbers strictly from 1 to 10.'),
              _buildRuleItem('2. The Toss', 'Both players submit a number. If the sum is odd, ODD wins; if even, EVEN wins. Winner chooses to Bat or Bowl.'),
              _buildRuleItem('3. Batting & Bowling', 'Each ball, both pick a number simultaneously. If numbers differ, batter scores their chosen number. Bowler scores 0.'),
              _buildRuleItem('4. Wicket (OUT)', 'If both pick the exact same number, the batter is OUT! 1 wicket ends the innings.'),
              _buildRuleItem('5. Target & Chase', 'Target is 1st innings total + 1. If 2nd batter hits target, they win! If out below target, 1st batter wins.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: GameColors.lime),
            child: const Text('GOT IT!', style: TextStyle(color: GameColors.background, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 13, color: GameColors.textPrimary)),
          const SizedBox(height: 2),
          Text(body, style: GameTypography.caption.copyWith(color: GameColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
