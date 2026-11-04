import 'game_enums.dart';

class PlayerInfo {
  final String id;
  final String name;
  final Parity? parity;
  final int seriesScore;
  final int timeoutPoints;

  const PlayerInfo({
    required this.id,
    required this.name,
    this.parity,
    this.seriesScore = 0,
    this.timeoutPoints = 0,
  });

  PlayerInfo copyWith({
    String? id,
    String? name,
    Parity? parity,
    int? seriesScore,
    int? timeoutPoints,
  }) {
    return PlayerInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      parity: parity ?? this.parity,
      seriesScore: seriesScore ?? this.seriesScore,
      timeoutPoints: timeoutPoints ?? this.timeoutPoints,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parity': parity?.name,
        'seriesScore': seriesScore,
        'timeoutPoints': timeoutPoints,
      };

  factory PlayerInfo.fromJson(Map<String, dynamic> json) {
    return PlayerInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      parity: json['parity'] != null
          ? Parity.values.byName(json['parity'] as String)
          : null,
      seriesScore: json['seriesScore'] as int? ?? 0,
      timeoutPoints: json['timeoutPoints'] as int? ?? 0,
    );
  }
}
