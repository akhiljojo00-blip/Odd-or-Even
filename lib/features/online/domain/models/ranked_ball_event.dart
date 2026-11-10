/// Server-authoritative resolved delivery event for an active Online Ranked match.
/// Synchronized with `public.ranked_ball_events`.
class RankedBallEvent {
  final String id;
  final String matchId;
  final int inningsNo;
  final int ballNo;
  final String batterId;
  final String bowlerId;
  final int batterNumber;
  final int bowlerNumber;
  final int runsScored;
  final bool isWicket;
  final int cumulativeRuns;
  final DateTime? createdAt;

  const RankedBallEvent({
    required this.id,
    required this.matchId,
    required this.inningsNo,
    required this.ballNo,
    required this.batterId,
    required this.bowlerId,
    required this.batterNumber,
    required this.bowlerNumber,
    required this.runsScored,
    required this.isWicket,
    required this.cumulativeRuns,
    this.createdAt,
  });

  /// True if the delivery resulted in a boundary (4 or 6 runs).
  bool get isBoundary => runsScored == 4 || runsScored == 6;

  factory RankedBallEvent.fromJson(Map<String, dynamic> json) {
    return RankedBallEvent(
      id: json['id'] as String? ?? '',
      matchId: json['match_id'] as String? ?? '',
      inningsNo: (json['innings_no'] as num?)?.toInt() ?? 1,
      ballNo: (json['ball_no'] as num?)?.toInt() ?? 1,
      batterId: json['batter_id'] as String? ?? '',
      bowlerId: json['bowler_id'] as String? ?? '',
      batterNumber: (json['batter_number'] as num?)?.toInt() ?? 0,
      bowlerNumber: (json['bowler_number'] as num?)?.toInt() ?? 0,
      runsScored: (json['runs_scored'] as num?)?.toInt() ?? 0,
      isWicket: json['is_wicket'] as bool? ?? false,
      cumulativeRuns: (json['cumulative_runs'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'match_id': matchId,
      'innings_no': inningsNo,
      'ball_no': ballNo,
      'batter_id': batterId,
      'bowler_id': bowlerId,
      'batter_number': batterNumber,
      'bowler_number': bowlerNumber,
      'runs_scored': runsScored,
      'is_wicket': isWicket,
      'cumulative_runs': cumulativeRuns,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
