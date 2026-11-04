import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';
import '../../../../core/utils/haptics_util.dart';
import '../../../../core/utils/sound_util.dart';

class NumberPad extends StatefulWidget {
  final int? selectedNumber;
  final ValueChanged<int> onNumberSelected;
  final VoidCallback onConfirm;
  final bool isSubmitting;
  final bool autoModeEnabled;
  final VoidCallback? onAutoPick;

  const NumberPad({
    super.key,
    required this.selectedNumber,
    required this.onNumberSelected,
    required this.onConfirm,
    this.isSubmitting = false,
    this.autoModeEnabled = false,
    this.onAutoPick,
  });

  @override
  State<NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<NumberPad> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Number grid: 2 rows of 5 numbers (1-5 and 6-10)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [1, 2, 3, 4, 5].map(_buildNumberButton).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [6, 7, 8, 9, 10].map(_buildNumberButton).toList(),
        ),
        const SizedBox(height: 20),
        // Action row: Confirm & Auto pick
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (widget.autoModeEnabled && widget.onAutoPick != null) ...[
                OutlinedButton.icon(
                  onPressed: widget.isSubmitting ? null : widget.onAutoPick,
                  icon: const Icon(Icons.flash_on, color: GameColors.amber),
                  label: Text('AUTO', style: GameTypography.caption.copyWith(color: GameColors.amber)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GameColors.amber),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: widget.selectedNumber != null && !widget.isSubmitting
                        ? () {
                            HapticsUtil.mediumTap();
                            SoundUtil.playSubmit();
                            widget.onConfirm();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.lime,
                      foregroundColor: GameColors.background,
                      disabledBackgroundColor: GameColors.surfaceElevated,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: widget.isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: GameColors.background,
                            ),
                          )
                        : Text(
                            widget.selectedNumber != null
                                ? 'LOCK IN NUMBER ${widget.selectedNumber}'
                                : 'SELECT A NUMBER (1 - 10)',
                            style: GameTypography.headlineMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: widget.selectedNumber != null
                                  ? GameColors.background
                                  : GameColors.textMuted,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNumberButton(int number) {
    final isSelected = widget.selectedNumber == number;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isSubmitting
                ? null
                : () {
                    HapticsUtil.lightTap();
                    SoundUtil.playTap();
                    widget.onNumberSelected(number);
                  },
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 58,
              decoration: BoxDecoration(
                color: isSelected ? GameColors.lime : GameColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? GameColors.lime : GameColors.glassBorder,
                  width: isSelected ? 2.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: GameColors.lime.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: GameTypography.displayMedium.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? GameColors.background : GameColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
