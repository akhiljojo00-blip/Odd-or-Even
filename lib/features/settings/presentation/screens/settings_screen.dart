import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/utils/sound_util.dart';
import '../../../../core/widgets/creator_footer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = SoundUtil.enabled;
  bool _hapticsEnabled = HapticsUtil.enabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('SETTINGS', style: GameTypography.headlineMedium),
        centerTitle: true,
      ),
      bottomNavigationBar: const CreatorFooter(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
            _buildSectionHeader('AUDIO & HAPTICS'),
            const SizedBox(height: 10),
            _buildSwitchTile(
              title: 'Sound Effects',
              subtitle: 'Tactile clicks, submit cues and wicket alerts',
              value: _soundEnabled,
              icon: Icons.volume_up_rounded,
              onChanged: (val) {
                setState(() {
                  _soundEnabled = val;
                  SoundUtil.enabled = val;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildSwitchTile(
              title: 'Haptic Feedback',
              subtitle: 'Vibrations for number taps and wickets',
              value: _hapticsEnabled,
              icon: Icons.vibration_rounded,
              onChanged: (val) {
                setState(() {
                  _hapticsEnabled = val;
                  HapticsUtil.enabled = val;
                });
                if (val) HapticsUtil.mediumTap();
              },
            ),
            const SizedBox(height: 28),

            _buildSectionHeader('ABOUT THE GAME'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: GameColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: GameColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Odd or Even v1.0.0', style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'A production mobile hand-cricket duel game built with Flutter, Riverpod, and Supabase PostgreSQL.',
                    style: GameTypography.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('Engineered by Antigravity Autonomous Team', style: GameTypography.caption.copyWith(color: GameColors.lime)),
                ],
              ),
            ),
          ],
        ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GameTypography.caption.copyWith(
        color: GameColors.lime,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: GameColors.lime, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: GameTypography.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: GameColors.lime,
            activeTrackColor: GameColors.lime.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
