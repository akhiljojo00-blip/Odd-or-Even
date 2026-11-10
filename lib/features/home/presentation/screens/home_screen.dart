import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../widgets/arcade_centerpiece.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (AppConfig.isStaging) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFF9800), width: 1.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.science_outlined, color: Color(0xFFFF9800), size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'STAGING ENVIRONMENT (hywownmlimseyboraosl)',
                                overflow: TextOverflow.ellipsis,
                                style: GameTypography.caption.copyWith(
                                  color: const Color(0xFFFF9800),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Top Bar with Status Badge & Header Action Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: GameColors.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: GameColors.glassBorder),
                            boxShadow: [
                              BoxShadow(
                                color: GameColors.lime.withValues(alpha: 0.15),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: GameColors.lime,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: GameColors.lime,
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'READY TO PLAY',
                                style: GameTypography.caption.copyWith(
                                  color: GameColors.lime,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _buildGlassIconButton(
                              icon: Icons.person_outline_rounded,
                              tooltip: 'Profile',
                              onPressed: () {
                                HapticsUtil.lightTap();
                                context.push('/profile');
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildGlassIconButton(
                              icon: Icons.history_rounded,
                              tooltip: 'Match History',
                              onPressed: () {
                                HapticsUtil.lightTap();
                                context.push('/history');
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildGlassIconButton(
                              icon: Icons.emoji_events_outlined,
                              tooltip: 'Leaderboard',
                              onPressed: () {
                                HapticsUtil.lightTap();
                                context.push('/ranked-leaderboard');
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildGlassIconButton(
                              icon: Icons.settings_outlined,
                              tooltip: 'Settings',
                              onPressed: () {
                                HapticsUtil.lightTap();
                                context.push('/settings');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title Header with Glowing Arcade Look
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFFDE68A), Color(0xFFFBBF24)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: Text(
                        'ODD OR EVEN',
                        textAlign: TextAlign.center,
                        style: GameTypography.displayLarge.copyWith(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.0,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: GameColors.gold.withValues(alpha: 0.6),
                              blurRadius: 16,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CLASSIC FINGER CRICKET DUEL',
                      textAlign: TextAlign.center,
                      style: GameTypography.caption.copyWith(
                        letterSpacing: 2.0,
                        color: GameColors.cyanBright,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Arcade Centerpiece Emblem
                    const Center(
                      child: ArcadeCenterpiece(size: 130),
                    ),
                    const SizedBox(height: 14),

                    // Game Mode Cards
                    _buildArcadeGameCard(
                      context: context,
                      title: 'PASS & PLAY',
                      subtitle: 'Local 2-player on one device with privacy screen',
                      icon: Icons.phone_android_rounded,
                      gradient: GameColors.cardGradientPassPlay,
                      accentColor: GameColors.mint,
                      badgeText: 'OFFLINE READY',
                      onTap: () {
                        HapticsUtil.mediumTap();
                        context.push('/offline-setup');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildArcadeGameCard(
                      context: context,
                      title: 'VS COMPUTER',
                      subtitle: 'Single-player offline match with Easy, Medium, or Hard AI',
                      icon: Icons.smart_toy_outlined,
                      gradient: GameColors.cardGradientVsComputer,
                      accentColor: GameColors.cyanBright,
                      badgeText: 'SOLO AI',
                      onTap: () {
                        HapticsUtil.mediumTap();
                        context.push('/vs-computer-setup');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildArcadeGameCard(
                      context: context,
                      title: 'VS COMPUTER RANKED',
                      subtitle: 'Competitive solo ladder with progressive 10-tier AI & star progression',
                      icon: Icons.military_tech_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFD97706), Color(0xFFF59E0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      accentColor: GameColors.goldMetallic,
                      badgeText: 'RANKED',
                      onTap: () {
                        HapticsUtil.mediumTap();
                        context.push('/vs-computer-ranked-setup');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildArcadeGameCard(
                      context: context,
                      title: 'ONLINE ROOMS',
                      subtitle: 'Host or join private matches with 6-character room codes',
                      icon: Icons.meeting_room_rounded,
                      gradient: GameColors.cardGradientOnline,
                      accentColor: GameColors.electricViolet,
                      badgeText: 'MULTIPLAYER',
                      onTap: () {
                        HapticsUtil.mediumTap();
                        context.push('/online-lobby');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildArcadeGameCard(
                      context: context,
                      title: 'ONLINE RANKED',
                      subtitle: 'Competitive online ladder with MMR matchmaking, stars & 10 tiers',
                      icon: Icons.workspace_premium_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF9333EA), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      accentColor: GameColors.goldBright,
                      badgeText: 'ONLINE LADDER',
                      onTap: () {
                        HapticsUtil.mediumTap();
                        context.push('/ranked-matchmaking');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildArcadeGameCard(
                      context: context,
                      title: 'QUICK MATCH',
                      subtitle: 'Instant 1v1 matchmaking with online players',
                      icon: Icons.bolt_rounded,
                      gradient: GameColors.cardGradientQuickMatch,
                      accentColor: GameColors.goldBright,
                      badgeText: 'FAST PAIRING',
                      onTap: () {
                        HapticsUtil.mediumTap();
                        context.push('/matchmaking');
                      },
                    ),
                    const SizedBox(height: 10),

                    // Rules Helper Button
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showRulesDialog(context),
                        icon: const Icon(Icons.help_outline_rounded, size: 16, color: GameColors.textSecondary),
                        label: Text(
                          'How to Play Odd or Even',
                          style: GameTypography.caption.copyWith(
                            color: GameColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const CreatorFooter(padding: EdgeInsets.only(top: 2, bottom: 2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GameColors.glassBorder),
      ),
      child: IconButton(
        icon: Icon(icon, color: GameColors.textSecondary, size: 20),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildArcadeGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required Color accentColor,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: accentColor.withValues(alpha: 0.3),
        highlightColor: accentColor.withValues(alpha: 0.15),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: GameTypography.headlineMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            badgeText,
                            style: GameTypography.caption.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GameTypography.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: GameColors.glassBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.sports_cricket, color: GameColors.gold),
            const SizedBox(width: 10),
            Text(
              'HOW TO PLAY',
              style: GameTypography.headlineMedium.copyWith(
                color: GameColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.lime,
              foregroundColor: GameColors.backgroundDeep,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('GOT IT!', style: TextStyle(fontWeight: FontWeight.w900)),
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
