class BallEvent {
  final int inningsNo;
  final int ballNo;
  final String batterId;
  final String bowlerId;
  final int batterNumber;
  final int bowlerNumber;
  final int runsScored;
  final bool isWicket;
  final int cumulativeRuns;

  const BallEvent({
    required this.inningsNo,
    required this.ballNo,
    required this.batterId,
    required this.bowlerId,
    required this.batterNumber,
    required this.bowlerNumber,
    required this.runsScored,
    required this.isWicket,
    required this.cumulativeRuns,
  });

  Map<String, dynamic> toJson() => {
        'inningsNo': inningsNo,
        'ballNo': ballNo,
        'batterId': batterId,
        'bowlerId': bowlerId,
        'batterNumber': batterNumber,
        'bowlerNumber': bowlerNumber,
        'runsScored': runsScored,
        'isWicket': isWicket,
        'cumulativeRuns': cumulativeRuns,
      };

  factory BallEvent.fromJson(Map<String, dynamic> json) {
    return BallEvent(
      inningsNo: (json['inningsNo'] ?? json['innings_no']) as int,
      ballNo: (json['ballNo'] ?? json['ball_no']) as int,
      batterId: (json['batterId'] ?? json['batter_id']) as String,
      bowlerId: (json['bowlerId'] ?? json['bowler_id']) as String,
      batterNumber: (json['batterNumber'] ?? json['batter_number']) as int,
      bowlerNumber: (json['bowlerNumber'] ?? json['bowler_number']) as int,
      runsScored: (json['runsScored'] ?? json['runs_scored']) as int,
      isWicket: (json['isWicket'] ?? json['is_wicket']) as bool,
      cumulativeRuns: (json['cumulativeRuns'] ?? json['cumulative_runs']) as int,
    );
  }
}
