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
    final playerColor = isPlayer1 ? GameColors.electricViolet : GameColors.cyanBright;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GameColors.surfaceElevated.withValues(alpha: 0.9),
            GameColors.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMyTurn ? playerColor : GameColors.glassBorder,
          width: isMyTurn ? 2.0 : 1.2,
        ),
        boxShadow: [
          if (isMyTurn)
            BoxShadow(
              color: playerColor.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  playerColor.withValues(alpha: 0.4),
                  playerColor.withValues(alpha: 0.15),
                ],
              ),
              border: Border.all(color: playerColor, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
              style: GameTypography.headlineMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  player.name,
                  style: GameTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (player.parity != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: playerColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: playerColor.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        player.parity!.label,
                        style: GameTypography.caption.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: playerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  if (activeRole != null) ...[
                    Icon(
                      activeRole == CricketRole.bat ? Icons.sports_cricket : Icons.sports_baseball,
                      size: 13,
                      color: activeRole == CricketRole.bat ? GameColors.mint : GameColors.goldBright,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      activeRole!.label,
                      style: GameTypography.caption.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: activeRole == CricketRole.bat ? GameColors.mint : GameColors.goldBright,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    'Pts: ${player.seriesScore}/$seriesTarget',
                    style: GameTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: GameColors.goldBright,
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
