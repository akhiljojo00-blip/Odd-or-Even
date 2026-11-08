import 'game_enums.dart';

class MatchConfig {
  final GameMode gameMode;
  final int? overs; // null = unlimited overs
  final int decisionTimerSeconds;
  final bool autoModeEnabled;
  final int seriesTargetPoints;
  final int maxChoice;

  const MatchConfig({
    this.gameMode = GameMode.standard,
    this.overs,
    this.decisionTimerSeconds = 10,
    this.autoModeEnabled = false,
    this.seriesTargetPoints = 6,
    this.maxChoice = 6,
  });

  int? get maxBalls => overs != null ? overs! * 6 : null;

  MatchConfig copyWith({
    GameMode? gameMode,
    int? overs,
    bool clearOvers = false,
    int? decisionTimerSeconds,
    bool? autoModeEnabled,
    int? seriesTargetPoints,
    int? maxChoice,
  }) {
    return MatchConfig(
      gameMode: gameMode ?? this.gameMode,
      overs: clearOvers ? null : (overs ?? this.overs),
      decisionTimerSeconds: decisionTimerSeconds ?? this.decisionTimerSeconds,
      autoModeEnabled: autoModeEnabled ?? this.autoModeEnabled,
      seriesTargetPoints: seriesTargetPoints ?? this.seriesTargetPoints,
      maxChoice: maxChoice ?? this.maxChoice,
    );
  }

  Map<String, dynamic> toJson() => {
        'gameMode': gameMode.name,
        'overs': overs,
        'decisionTimerSeconds': decisionTimerSeconds,
        'autoModeEnabled': autoModeEnabled,
        'seriesTargetPoints': seriesTargetPoints,
        'maxChoice': maxChoice,
      };

  factory MatchConfig.fromJson(Map<String, dynamic> json) {
    return MatchConfig(
      gameMode: json['gameMode'] == 'fast' ? GameMode.fast : GameMode.standard,
      overs: json['overs'] as int?,
      decisionTimerSeconds: json['decisionTimerSeconds'] as int? ?? 10,
      autoModeEnabled: json['autoModeEnabled'] as bool? ?? false,
      seriesTargetPoints: json['seriesTargetPoints'] as int? ?? 6,
      // CRITICAL BACKWARD COMPATIBILITY: Legacy serialized MatchConfig data without maxChoice must deserialize with maxChoice = 10.
      maxChoice: json['maxChoice'] as int? ?? 10,
    );
  }
}
