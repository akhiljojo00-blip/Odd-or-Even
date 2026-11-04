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
      inningsNo: json['inningsNo'] as int,
      ballNo: json['ballNo'] as int,
      batterId: json['batterId'] as String,
      bowlerId: json['bowlerId'] as String,
      batterNumber: json['batterNumber'] as int,
      bowlerNumber: json['bowlerNumber'] as int,
      runsScored: json['runsScored'] as int,
      isWicket: json['isWicket'] as bool,
      cumulativeRuns: json['cumulativeRuns'] as int,
    );
  }
}
