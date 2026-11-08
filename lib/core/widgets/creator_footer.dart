import 'package:flutter/material.dart';
import '../theme/game_colors.dart';
import '../theme/game_typography.dart';

/// A premium, responsive creator signature footer.
/// Displays Instagram handle on the left and creator credit on the right.
class CreatorFooter extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const CreatorFooter({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GameTypography.caption.copyWith(
      fontSize: 11,
      letterSpacing: 0.5,
      color: GameColors.textMuted,
    );

    final leftWidget = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'ig - ',
            style: textStyle.copyWith(color: GameColors.textMuted),
          ),
          TextSpan(
            text: '@__refle_xoo_7',
            style: textStyle.copyWith(
              color: GameColors.lime,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final rightWidget = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Created By ',
            style: textStyle.copyWith(color: GameColors.textMuted),
          ),
          TextSpan(
            text: 'Akhil Jojo',
            style: textStyle.copyWith(
              color: GameColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // If the available width is sufficiently wide, render on a single horizontal row
            if (constraints.maxWidth >= 360) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(child: leftWidget),
                  const SizedBox(width: 8),
                  Flexible(child: rightWidget),
                ],
              );
            }

            // On ultra-narrow screens, stack cleanly with centered alignment
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leftWidget,
                const SizedBox(height: 3),
                rightWidget,
              ],
            );
          },
        ),
      ),
    );
  }
}
