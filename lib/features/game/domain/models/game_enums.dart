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

  static MatchPhase fromValue(String value) {
    final normalized = value.replaceAll('_', '').toLowerCase();
    for (final p in MatchPhase.values) {
      if (p.name.toLowerCase() == normalized) return p;
    }
    return MatchPhase.tossInput;
  }
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

  static MatchResultType? fromValue(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll('_', '').toLowerCase();
    if (normalized == 'win' || normalized == 'chaserwon') return MatchResultType.chaserWon;
    if (normalized == 'defenderwon') return MatchResultType.defenderWon;
    if (normalized == 'tie') return MatchResultType.tie;
    if (normalized == 'forfeit') return MatchResultType.forfeit;
    return null;
  }
}
