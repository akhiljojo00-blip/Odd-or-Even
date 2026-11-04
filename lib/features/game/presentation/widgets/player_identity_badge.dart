import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../domain/models/game_enums.dart';
import '../../domain/models/player_info.dart';

class PlayerIdentityBadge extends StatelessWidget {
  final PlayerInfo player;
  final bool isPlayer1;
  final CricketRole? activeRole;
  final bool isMyTurn;
  final int seriesTarget;

  const PlayerIdentityBadge({
    super.key,
    required this.player,
    required this.isPlayer1,
    this.activeRole,
    this.isMyTurn = false,
    this.seriesTarget = 6,
  });

  @override
  Widget build(BuildContext context) {
    final playerColor = isPlayer1 ? GameColors.player1 : GameColors.player2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMyTurn ? playerColor : GameColors.glassBorder,
          width: isMyTurn ? 2.0 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: playerColor.withValues(alpha: 0.2),
            child: Text(
              player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
              style: GameTypography.headlineMedium.copyWith(
                fontSize: 16,
                color: playerColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                style: GameTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (player.parity != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: playerColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        player.parity!.label,
                        style: GameTypography.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: playerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (activeRole != null) ...[
                    Icon(
                      activeRole == CricketRole.bat ? Icons.sports_cricket : Icons.sports_baseball,
                      size: 13,
                      color: activeRole == CricketRole.bat ? GameColors.lime : GameColors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activeRole!.label,
                      style: GameTypography.caption.copyWith(
                        fontSize: 10,
                        color: activeRole == CricketRole.bat ? GameColors.lime : GameColors.amber,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    'Pts: ${player.seriesScore}/$seriesTarget',
                    style: GameTypography.caption.copyWith(
                      fontSize: 10,
                      color: GameColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
