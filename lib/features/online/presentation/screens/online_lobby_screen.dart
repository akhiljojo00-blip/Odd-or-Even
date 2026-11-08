import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../../game/domain/models/match_config.dart';
import '../../data/supabase_match_repository.dart';

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _roomCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateRoom() async {
    HapticsUtil.mediumTap();
    final repo = ref.read(supabaseMatchRepositoryProvider);
    if (!repo.isConfigured) {
      _showNotConfiguredDialog();
      return;
    }

    setState(() => _isLoading = true);
    final userId = await repo.ensureAuthenticatedUser();
    if (userId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        final authErr = repo.lastAuthError ?? 'Authentication failed. Please verify Supabase setup.';
        _showAuthErrorDialog(authErr);
      }
      return;
    }

    final res = await repo.createRoom(const MatchConfig());
    setState(() => _isLoading = false);

    if (res != null && mounted) {
      final roomId = res['room_id'] as String;
      final roomCode = res['room_code'] as String;
      context.push('/room/$roomId?code=$roomCode&isHost=true');
    } else if (mounted) {
      final err = repo.lastRoomError ?? 'Failed to create room. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: GameColors.wicket,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _handleJoinRoom() async {
    HapticsUtil.mediumTap();
    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid room code')),
      );
      return;
    }

    final repo = ref.read(supabaseMatchRepositoryProvider);
    if (!repo.isConfigured) {
      _showNotConfiguredDialog();
      return;
    }

    setState(() => _isLoading = true);
    final userId = await repo.ensureAuthenticatedUser();
    if (userId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        final authErr = repo.lastAuthError ?? 'Authentication failed. Please verify Supabase setup.';
        _showAuthErrorDialog(authErr);
      }
      return;
    }

    final res = await repo.joinRoom(code);
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (res != null) {
      final roomId = res['room_id'] as String;
      context.push('/room/$roomId?code=$code&isHost=false');
    } else {
      final err = repo.lastRoomError ?? 'Could not find room or room is full/expired';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: GameColors.wicket,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showAuthErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: GameColors.wicket),
            const SizedBox(width: 10),
            Text('Authentication Error', style: GameTypography.headlineMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error,
              style: GameTypography.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GameColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GameColors.glassBorder),
              ),
              child: Text(
                'Supabase Dashboard -> Authentication -> Providers -> Anonymous -> Enable "Allow anonymous sign-ins".',
                style: GameTypography.caption.copyWith(color: GameColors.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: GameColors.lime),
            child: const Text('OK', style: TextStyle(color: GameColors.background, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNotConfiguredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: GameColors.amber),
            const SizedBox(width: 10),
            Text('Supabase Setup', style: GameTypography.headlineMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Online real-time multiplayer requires active Supabase project credentials.',
              style: GameTypography.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'To connect your cloud database:',
              style: GameTypography.caption.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '1. Apply migrations in supabase/migrations/\n2. Provide SUPABASE_URL and SUPABASE_ANON_KEY\n3. Enjoy server-authoritative live matches!',
              style: GameTypography.caption.copyWith(color: GameColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: GameColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/offline-setup');
            },
            style: ElevatedButton.styleFrom(backgroundColor: GameColors.lime),
            child: const Text('Play Pass & Play', style: TextStyle(color: GameColors.background, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            HapticsUtil.lightTap();
            context.go('/');
          },
        ),
        title: Text(
          'ONLINE MULTIPLAYER',
          style: GameTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: TabBar(
                controller: _tabController,
                indicatorColor: GameColors.electricViolet,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: GameColors.textMuted,
                labelStyle: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                tabs: const [
                  Tab(text: 'CREATE ROOM'),
                  Tab(text: 'JOIN ROOM'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCreateRoomTab(),
                  _buildJoinRoomTab(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const CreatorFooter(),
    );
  }

  Widget _buildCreateRoomTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: GameColors.surfaceGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: GameColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: GameColors.cardGradientOnline,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Private 1v1 Room',
                        style: GameTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Generate a 6-character room code and duel anywhere in the world',
                        style: GameTypography.caption.copyWith(color: GameColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleCreateRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: GameColors.cardGradientOnline,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: GameColors.electricViolet.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'CREATE ROOM CODE',
                          style: GameTypography.headlineMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildJoinRoomTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ENTER 6-CHARACTER ROOM CODE',
            style: GameTypography.caption.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: GameColors.cyanBright,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _roomCodeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: GameTypography.displayMedium.copyWith(
              letterSpacing: 8.0,
              fontWeight: FontWeight.w900,
              color: GameColors.cyanBright,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'CODE',
              hintStyle: GameTypography.displayMedium.copyWith(
                letterSpacing: 8.0,
                color: GameColors.textMuted.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: GameColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: GameColors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: GameColors.glassBorder, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: GameColors.cyanBright, width: 2),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleJoinRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0891B2), Color(0xFF06B6D4), Color(0xFF22D3EE)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: GameColors.cyan.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'JOIN ROOM',
                          style: GameTypography.headlineMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
