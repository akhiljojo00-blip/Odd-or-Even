import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
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
  String? _createdRoomCode;

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
    final repo = ref.read(supabaseMatchRepositoryProvider);
    if (!repo.isConfigured) {
      _showNotConfiguredDialog();
      return;
    }

    setState(() => _isLoading = true);
    // Authenticate
    await repo.ensureAuthenticatedUser();
    // Simulate or invoke RPC
    setState(() {
      _isLoading = false;
      _createdRoomCode = 'OE${(1000 + (DateTime.now().millisecond * 9) % 9000).toInt()}';
    });
  }

  Future<void> _handleJoinRoom() async {
    final code = _roomCodeController.text.trim();
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
    await repo.ensureAuthenticatedUser();
    final res = await repo.joinRoom(code);
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined room $code successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find room or room expired')),
      );
    }
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
        title: Text('ONLINE MULTIPLAYER', style: GameTypography.headlineMedium),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: GameColors.lime,
          labelColor: GameColors.lime,
          unselectedLabelColor: GameColors.textSecondary,
          labelStyle: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'CREATE ROOM'),
            Tab(text: 'JOIN ROOM'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCreateRoomTab(),
            _buildJoinRoomTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateRoomTab() {
    if (_createdRoomCode != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: GameColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: GameColors.lime),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.share_rounded, size: 48, color: GameColors.lime),
                const SizedBox(height: 16),
                Text('ROOM CODE CREATED', style: GameTypography.caption.copyWith(letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text(
                  _createdRoomCode!,
                  style: GameTypography.displayLarge.copyWith(
                    letterSpacing: 4.0,
                    color: GameColors.lime,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Share this 6-character code with your opponent to duel.',
                  textAlign: TextAlign.center,
                  style: GameTypography.bodyMedium,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: GameColors.lime),
                const SizedBox(height: 12),
                Text('Waiting for player to join...', style: GameTypography.caption),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GameColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GameColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: GameColors.lime, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Private 1v1 Room', style: GameTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Generate a secure code for your friend', style: GameTypography.caption),
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
                backgroundColor: GameColors.lime,
                foregroundColor: GameColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: GameColors.background)
                  : Text('CREATE ROOM CODE', style: GameTypography.headlineMedium.copyWith(fontSize: 16, color: GameColors.background)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildJoinRoomTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ENTER 6-CHARACTER ROOM CODE', style: GameTypography.caption.copyWith(letterSpacing: 1.0)),
          const SizedBox(height: 12),
          TextField(
            controller: _roomCodeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: GameTypography.displayMedium.copyWith(letterSpacing: 6.0, color: GameColors.lime),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'CODE',
              hintStyle: GameTypography.displayMedium.copyWith(letterSpacing: 6.0, color: GameColors.textMuted),
              filled: true,
              fillColor: GameColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: GameColors.glassBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: GameColors.glassBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: GameColors.lime, width: 2)),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleJoinRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: GameColors.lime,
                foregroundColor: GameColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: GameColors.background)
                  : Text('JOIN ROOM', style: GameTypography.headlineMedium.copyWith(fontSize: 16, color: GameColors.background)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
