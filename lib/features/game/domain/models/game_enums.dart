enum GameMode {
  standard,
  fast;

  String get label => this == GameMode.standard ? 'Standard' : 'Fast (Auto)';
}

enum Parity {
  odd,
  even;

  String get label => this == Parity.odd ? 'ODD' : 'EVEN';

  Parity get opposite => this == Parity.odd ? Parity.even : Parity.odd;
}

enum CricketRole {
  bat,
  bowl;

  String get label => this == CricketRole.bat ? 'Batting' : 'Bowling';

  CricketRole get opposite => this == CricketRole.bat ? CricketRole.bowl : CricketRole.bat;
}

enum MatchPhase {
  lobbySetup,
  configAgreement,
  parityAssignment,
  tossInput,
  tossReveal,
  roleSelection,
  firstInnings,
  inningsBreak,
  secondInnings,
  matchFinished,
  seriesFinished,
  matchForfeited;

  bool get isInningsActive =>
      this == MatchPhase.firstInnings || this == MatchPhase.secondInnings;
}

enum MatchResultType {
  chaserWon,
  defenderWon,
  tie,
  forfeit;

  String get description {
    switch (this) {
      case MatchResultType.chaserWon:
        return 'Chased Target Successfully';
      case MatchResultType.defenderWon:
        return 'Defended Target Successfully';
      case MatchResultType.tie:
        return 'Scores Tied';
      case MatchResultType.forfeit:
        return 'Opponent Forfeited';
    }
  }
}
