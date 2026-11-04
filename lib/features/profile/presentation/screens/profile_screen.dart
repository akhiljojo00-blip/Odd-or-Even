import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../online/data/supabase_match_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController(text: 'Player 1');
  int _avatarIndex = 0;
  bool _isLoading = true;
  int _matchesPlayed = 0;
  int _matchesWon = 0;
  int _matchesLost = 0;
  int _matchesTied = 0;

  final List<IconData> _avatarIcons = [
    Icons.sports_cricket,
    Icons.sports_baseball,
    Icons.emoji_events,
    Icons.bolt,
    Icons.shield,
    Icons.military_tech,
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    if (!repo.isConfigured) {
      setState(() => _isLoading = false);
      return;
    }

    final uid = await repo.ensureAuthenticatedUser();
    if (uid != null) {
      final profile = await repo.getProfile(uid);
      if (profile != null && mounted) {
        setState(() {
          _nameController.text = (profile['display_name'] as String?) ?? 'Player 1';
          _avatarIndex = (profile['avatar_index'] as int?) ?? 0;
          _matchesPlayed = (profile['matches_played'] as int?) ?? 0;
          _matchesWon = (profile['matches_won'] as int?) ?? 0;
          _matchesLost = (profile['matches_lost'] as int?) ?? 0;
          _matchesTied = (profile['matches_tied'] as int?) ?? 0;
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    HapticsUtil.mediumTap();
    final repo = ref.read(supabaseMatchRepositoryProvider);
    if (repo.isConfigured) {
      await repo.updateProfile(displayName: name, avatarIndex: _avatarIndex);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final winRate = _matchesPlayed > 0
        ? ((_matchesWon / _matchesPlayed) * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('PLAYER PROFILE', style: GameTypography.headlineMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: GameColors.lime))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar selection
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: GameColors.lime.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: GameColors.lime, width: 2),
                        ),
                        child: Icon(
                          _avatarIcons[_avatarIndex % _avatarIcons.length],
                          size: 48,
                          color: GameColors.lime,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_avatarIcons.length, (idx) {
                        final isSelected = _avatarIndex == idx;
                        return GestureDetector(
                          onTap: () => setState(() => _avatarIndex = idx),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? GameColors.lime : GameColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? GameColors.lime : GameColors.glassBorder,
                              ),
                            ),
                            child: Icon(
                              _avatarIcons[idx],
                              size: 18,
                              color: isSelected ? GameColors.background : GameColors.textSecondary,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Display Name Field
                    TextField(
                      controller: _nameController,
                      style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: const TextStyle(color: GameColors.lime),
                        filled: true,
                        fillColor: GameColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: GameColors.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: GameColors.lime, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stats Dashboard
                    Text('CAREER STATISTICS', style: GameTypography.caption.copyWith(letterSpacing: 1.2, color: GameColors.lime, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: GameColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GameColors.glassBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('MATCHES', '$_matchesPlayed', GameColors.textPrimary),
                              _buildStatItem('WINS', '$_matchesWon', GameColors.lime),
                              _buildStatItem('LOSSES', '$_matchesLost', GameColors.wicket),
                              _buildStatItem('TIED', '$_matchesTied', GameColors.gold),
                            ],
                          ),
                          const Divider(color: GameColors.glassBorder, height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('WIN RATE', style: GameTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                              Text('$winRate%', style: GameTypography.headlineMedium.copyWith(color: GameColors.lime)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GameColors.lime,
                          foregroundColor: GameColors.background,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'SAVE PROFILE',
                          style: GameTypography.headlineMedium.copyWith(fontSize: 16, color: GameColors.background),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GameTypography.scoreNumber.copyWith(fontSize: 24, color: color)),
        const SizedBox(height: 4),
        Text(label, style: GameTypography.caption.copyWith(fontSize: 10, letterSpacing: 0.5)),
      ],
    );
  }
}
