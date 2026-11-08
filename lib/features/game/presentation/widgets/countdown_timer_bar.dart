import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/game_colors.dart';
import '../../../../core/theme/game_typography.dart';

class CountdownTimerBar extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback onTimeout;
  final bool isPaused;
  final Key? resetKey;

  const CountdownTimerBar({
    super.key,
    required this.totalSeconds,
    required this.onTimeout,
    this.isPaused = false,
    this.resetKey,
  });

  @override
  State<CountdownTimerBar> createState() => _CountdownTimerBarState();
}

class _CountdownTimerBarState extends State<CountdownTimerBar> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant CountdownTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey ||
        oldWidget.totalSeconds != widget.totalSeconds) {
      _reset();
    } else if (oldWidget.isPaused != widget.isPaused) {
      if (widget.isPaused) {
        _timer?.cancel();
      } else {
        if (_timer == null || !_timer!.isActive) {
          _startTimer();
        }
      }
    }
  }

  void _reset() {
    _timer?.cancel();
    _remainingSeconds = widget.totalSeconds;
    if (!widget.isPaused) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.isPaused) return;

      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        setState(() {
          _remainingSeconds = 0;
        });
        timer.cancel();
        widget.onTimeout();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalSeconds > 0
        ? _remainingSeconds / widget.totalSeconds
        : 0.0;

    final Color barColor;
    if (progress > 0.5) {
      barColor = GameColors.lime;
    } else if (progress > 0.25) {
      barColor = GameColors.amber;
    } else {
      barColor = GameColors.wicket;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DECISION CLOCK',
                style: GameTypography.caption.copyWith(
                  letterSpacing: 1.0,
                  fontSize: 10,
                ),
              ),
              Text(
                '${_remainingSeconds}s',
                style: GameTypography.caption.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: GameColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
