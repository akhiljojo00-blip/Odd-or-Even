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
  final int maxNumber;

  const NumberPad({
    super.key,
    required this.selectedNumber,
    required this.onNumberSelected,
    required this.onConfirm,
    this.isSubmitting = false,
    this.autoModeEnabled = false,
    this.onAutoPick,
    this.maxNumber = 10,
  });

  @override
  State<NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<NumberPad> {
  void _handleConfirm() {
    if (widget.selectedNumber == null || widget.isSubmitting) return;
    HapticsUtil.mediumTap();
    SoundUtil.playSubmit();
    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.isSubmitting;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Number grid:
        if (widget.maxNumber == 6) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [1, 2, 3].map((n) => _buildNumberButton(n, busy)).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [4, 5, 6].map((n) => _buildNumberButton(n, busy)).toList(),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [1, 2, 3, 4, 5].map((n) => _buildNumberButton(n, busy)).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [6, 7, 8, 9, 10].map((n) => _buildNumberButton(n, busy)).toList(),
          ),
        ],
        const SizedBox(height: 18),

        // Action row: Confirm & Auto pick
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (widget.autoModeEnabled && widget.onAutoPick != null) ...[
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: GameColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GameColors.gold.withValues(alpha: 0.5)),
                  ),
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : widget.onAutoPick,
                    icon: const Icon(Icons.flash_on_rounded, color: GameColors.goldBright, size: 20),
                    label: Text(
                      'AUTO',
                      style: GameTypography.caption.copyWith(
                        color: GameColors.goldBright,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: widget.selectedNumber != null && !busy ? _handleConfirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: widget.selectedNumber != null && !busy
                            ? const LinearGradient(
                                colors: [Color(0xFF84CC16), Color(0xFF10B981)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  GameColors.surfaceElevated.withValues(alpha: 0.6),
                                  GameColors.surface.withValues(alpha: 0.6),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: widget.selectedNumber != null && !busy
                              ? Colors.white.withValues(alpha: 0.4)
                              : GameColors.glassBorder,
                          width: 1.5,
                        ),
                        boxShadow: widget.selectedNumber != null && !busy
                            ? [
                                BoxShadow(
                                  color: GameColors.lime.withValues(alpha: 0.45),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (widget.selectedNumber != null) ...[
                                    const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    widget.selectedNumber != null
                                        ? 'LOCK IN NUMBER ${widget.selectedNumber}'
                                        : 'SELECT A NUMBER (1 - ${widget.maxNumber})',
                                    style: GameTypography.headlineMedium.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                      color: widget.selectedNumber != null
                                          ? Colors.white
                                          : GameColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildNumberButton(int number, bool busy) {
    final isSelected = widget.selectedNumber == number;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy
                ? null
                : () {
                    HapticsUtil.lightTap();
                    SoundUtil.playTap();
                    widget.onNumberSelected(number);
                  },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 56,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          GameColors.surfaceElevated.withValues(alpha: 0.85),
                          GameColors.surface.withValues(alpha: 0.95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : GameColors.glassBorder.withValues(alpha: 0.5),
                  width: isSelected ? 2.2 : 1.2,
                ),
                boxShadow: [
                  if (isSelected) ...[
                    BoxShadow(
                      color: GameColors.electricViolet.withValues(alpha: 0.6),
                      blurRadius: 14,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: GameColors.cyan.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ] else ...[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: GameTypography.displayMedium.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : GameColors.textPrimary,
                  shadows: isSelected
                      ? const [
                          Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
