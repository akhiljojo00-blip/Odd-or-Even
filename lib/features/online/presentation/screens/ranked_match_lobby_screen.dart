import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/widgets/creator_footer.dart';
import '../../data/online_ranked_repository.dart';
import '../../domain/models/ranked_match.dart';

/// Temporary lobby destination for matched Online Ranked duels.
/// Displays authoritative match pairing details before gameplay handover in Phase 5C.3.
class RankedMatchLobbyScreen extends ConsumerStatefulWidget {
  final String matchId;

  const RankedMatchLobbyScreen({
    super.key,
    required this.matchId,
  });

  @override
  ConsumerState<RankedMatchLobbyScreen> createState() => _RankedMatchLobbyScreenState();
}

class _RankedMatchLobbyScreenState extends ConsumerState<RankedMatchLobbyScreen> {
  RankedMatch? _match;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMatchDetails();
  }

  Future<void> _loadMatchDetails() async {
    final repo = ref.read(onlineRankedRepositoryProvider);
    try {
      final match = await repo.getMatch(widget.matchId);
      if (mounted) {
        setState(() {
          _match = match;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(onlineRankedRepositoryProvider).currentUserId;
    final match = _match;

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          'MATCH FOUND',
          style: GameTypography.headlineMedium.copyWith(
            color: GameColors.goldBright,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: const CreatorFooter(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: GameColors.arcadeBackgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: GameColors.goldBright),
                      )
                    : _errorMessage != null
                        ? _buildErrorView()
                        : _buildMatchOverview(match, currentUid),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: GameColors.wicket, size: 48),
        const SizedBox(height: 16),
        Text(
          'Unable to Load Match Record',
          style: GameTypography.headlineMedium.copyWith(color: GameColors.wicket),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Unknown error',
          textAlign: TextAlign.center,
          style: GameTypography.bodyMedium.copyWith(color: GameColors.textSecondary),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/'),
          style: ElevatedButton.styleFrom(
            backgroundColor: GameColors.surfaceElevated,
            foregroundColor: Colors.white,
          ),
          child: const Text('Return to Home'),
        ),
      ],
    );
  }

  Widget _buildMatchOverview(RankedMatch? match, String? currentUid) {
    if (match == null) {
      return const Center(child: Text('Match record not found.'));
    }

    final isP1 = currentUid == match.player1Id;
    final myParity = isP1 ? match.player1Parity : match.player2Parity;
    final oppParity = isP1 ? match.player2Parity : match.player1Parity;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: GameColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GameColors.goldMetallic.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: GameColors.royalPurple.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: GameColors.lime.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GameColors.lime),
                ),
                child: Text(
                  'SERVER AUTHORITATIVE PAIRING',
                  style: GameTypography.caption.copyWith(
                    color: GameColors.lime,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Ranked Duel Ready',
                style: GameTypography.headlineLarge.copyWith(
                  color: GameColors.goldBright,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Match ID: ${match.id.substring(0, 8)}...',
                style: GameTypography.caption.copyWith(color: GameColors.cyanBright),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPlayerCard(
                    title: 'YOU',
                    parity: myParity.dbValue.toUpperCase(),
                    isHighlighted: true,
                  ),
                  Text(
                    'VS',
                    style: GameTypography.headlineLarge.copyWith(
                      color: GameColors.goldBright,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _buildPlayerCard(
                    title: 'OPPONENT',
                    parity: oppParity.dbValue.toUpperCase(),
                    isHighlighted: false,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GameColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Phase 5C.2 Matchmaking Successful!\nPhase 5C.3 will handle live toss and delivery handover.',
                  textAlign: TextAlign.center,
                  style: GameTypography.caption.copyWith(color: GameColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('OK, RETURN HOME'),
          style: ElevatedButton.styleFrom(
            backgroundColor: GameColors.goldMetallic,
            foregroundColor: GameColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCard({
    required String title,
    required String parity,
    required bool isHighlighted,
  }) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? GameColors.royalPurple.withValues(alpha: 0.3)
            : GameColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? GameColors.cyanBright : GameColors.glassBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GameTypography.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: isHighlighted ? GameColors.cyanBright : GameColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            parity,
            style: GameTypography.headlineMedium.copyWith(
              color: parity == 'ODD' ? GameColors.goldBright : GameColors.mint,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
