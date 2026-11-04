import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../game/domain/models/game_enums.dart';
import '../../../game/domain/models/match_config.dart';
import '../../../online/data/supabase_match_repository.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomCode;
  final bool isHost;

  const RoomScreen({
    super.key,
    required this.roomId,
    required this.roomCode,
    this.isHost = false,
  });

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  Timer? _pollTimer;
  MatchConfig _config = const MatchConfig();
  bool _hostConfirmed = false;
  bool _guestConfirmed = false;
  bool _hasGuestJoined = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkRoomStatus());
  }

  Future<void> _checkRoomStatus() async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    if (!repo.isConfigured) return;

    final room = await repo.getRoom(widget.roomId);
    if (room == null || !mounted) return;

    final activeMatchId = room['active_match_id'] as String?;
    if (activeMatchId != null && activeMatchId.isNotEmpty) {
      _pollTimer?.cancel();
      context.go('/online-play/$activeMatchId');
      return;
    }

    setState(() {
      _hasGuestJoined = room['guest_user_id'] != null;
      _hostConfirmed = room['host_confirmed'] as bool? ?? false;
      _guestConfirmed = room['guest_confirmed'] as bool? ?? false;
      if (room['config'] is Map<String, dynamic>) {
        _config = MatchConfig.fromJson(room['config'] as Map<String, dynamic>);
      }
    });
  }

  Future<void> _handleConfirmSettings() async {
    final repo = ref.read(supabaseMatchRepositoryProvider);
    HapticsUtil.mediumTap();

    if (!repo.isConfigured) {
      // Offline fallback: start simulated match
      context.go('/offline-play');
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await repo.confirmRoomConfig(widget.roomId, _config);
    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (res != null && res['status'] == 'started') {
      final matchId = res['match_id'] as String;
      _pollTimer?.cancel();
      context.go('/online-play/$matchId');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings confirmed! Waiting for opponent.')),
      );
    }
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    HapticsUtil.lightTap();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Room code ${widget.roomCode} copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmedByMe = widget.isHost ? _hostConfirmed : _guestConfirmed;

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('MATCH ROOM', style: GameTypography.headlineMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Room Code Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: GameColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GameColors.lime.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: GameColors.lime.withOpacity(0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text('SHARE ROOM CODE', style: GameTypography.caption.copyWith(letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.roomCode,
                          style: GameTypography.displayLarge.copyWith(
                            letterSpacing: 6.0,
                            color: GameColors.lime,
                            fontSize: 32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: GameColors.lime),
                          onPressed: _copyRoomCode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hasGuestJoined
                          ? 'Opponent has connected to room!'
                          : 'Waiting for opponent to enter this code...',
                      style: GameTypography.caption.copyWith(
                        color: _hasGuestJoined ? GameColors.lime : GameColors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Player Ready Statuses
              Row(
                children: [
                  Expanded(
                    child: _buildParticipantCard(
                      label: 'HOST',
                      isMe: widget.isHost,
                      isConfirmed: _hostConfirmed,
                      color: GameColors.player1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildParticipantCard(
                      label: 'GUEST',
                      isMe: !widget.isHost,
                      isConfirmed: _guestConfirmed,
                      color: GameColors.player2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text('MATCH SETTINGS AGREEMENT', style: GameTypography.caption.copyWith(letterSpacing: 1.2, color: GameColors.lime, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Config details
              _buildConfigOption(
                title: 'GAME MODE',
                value: _config.gameMode.label,
                icon: Icons.flash_on_rounded,
                onTap: isConfirmedByMe
                    ? null
                    : () {
                        setState(() {
                          _config = _config.copyWith(
                            gameMode: _config.gameMode == GameMode.standard
                                ? GameMode.fast
                                : GameMode.standard,
                          );
                        });
                      },
              ),
              const SizedBox(height: 10),

              _buildConfigOption(
                title: 'OVERS PER INNINGS',
                value: _config.overs != null ? '${_config.overs} Overs' : 'Unlimited',
                icon: Icons.sports_cricket,
                onTap: isConfirmedByMe
                    ? null
                    : () {
                        setState(() {
                          if (_config.overs == null) {
                            _config = _config.copyWith(overs: 1);
                          } else if (_config.overs == 1) {
                            _config = _config.copyWith(overs: 2);
                          } else if (_config.overs == 2) {
                            _config = _config.copyWith(overs: 5);
                          } else {
                            _config = _config.copyWith(clearOvers: true);
                          }
                        });
                      },
              ),
              const SizedBox(height: 10),

              _buildConfigOption(
                title: 'DECISION TIMER',
                value: '${_config.decisionTimerSeconds}s',
                icon: Icons.timer_outlined,
                onTap: isConfirmedByMe
                    ? null
                    : () {
                        setState(() {
                          final current = _config.decisionTimerSeconds;
                          final next = current == 5 ? 10 : (current == 10 ? 15 : (current == 15 ? 20 : (current == 20 ? 30 : 5)));
                          _config = _config.copyWith(decisionTimerSeconds: next);
                        });
                      },
              ),
              const SizedBox(height: 10),

              _buildConfigOption(
                title: 'SERIES TARGET',
                value: '${_config.seriesTargetPoints} Wins',
                icon: Icons.emoji_events_outlined,
                onTap: isConfirmedByMe
                    ? null
                    : () {
                        setState(() {
                          final current = _config.seriesTargetPoints;
                          final next = current == 1 ? 3 : (current == 3 ? 5 : (current == 5 ? 6 : (current == 6 ? 10 : 1)));
                          _config = _config.copyWith(seriesTargetPoints: next);
                        });
                      },
              ),
              const SizedBox(height: 32),

              // Action button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleConfirmSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConfirmedByMe ? GameColors.surfaceElevated : GameColors.lime,
                    foregroundColor: isConfirmedByMe ? GameColors.lime : GameColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : Text(
                          isConfirmedByMe ? 'SETTINGS CONFIRMED ✓' : 'CONFIRM SETTINGS',
                          style: GameTypography.headlineMedium.copyWith(
                            fontSize: 16,
                            color: isConfirmedByMe ? GameColors.lime : GameColors.background,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantCard({
    required String label,
    required bool isMe,
    required bool isConfirmed,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConfirmed ? GameColors.lime : GameColors.glassBorder,
          width: isConfirmed ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                isMe ? '$label (YOU)' : label,
                style: GameTypography.caption.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isConfirmed ? GameColors.lime.withOpacity(0.2) : GameColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isConfirmed ? 'READY ✓' : 'WAITING...',
              style: GameTypography.caption.copyWith(
                color: isConfirmed ? GameColors.lime : GameColors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigOption({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: GameColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GameColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: GameColors.lime, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: GameTypography.bodyMedium),
            ),
            Text(
              value,
              style: GameTypography.bodyLarge.copyWith(
                color: GameColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: GameColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}
