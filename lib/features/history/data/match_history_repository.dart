import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../game/domain/models/game_match_state.dart';

class MatchHistoryRecord {
  final String matchId;
  final String player1Name;
  final String player2Name;
  final int firstInningsRuns;
  final int secondInningsRuns;
  final String? winnerName;
  final String resultSummary;
  final DateTime playedAt;

  const MatchHistoryRecord({
    required this.matchId,
    required this.player1Name,
    required this.player2Name,
    required this.firstInningsRuns,
    required this.secondInningsRuns,
    this.winnerName,
    required this.resultSummary,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'player1Name': player1Name,
        'player2Name': player2Name,
        'firstInningsRuns': firstInningsRuns,
        'secondInningsRuns': secondInningsRuns,
        'winnerName': winnerName,
        'resultSummary': resultSummary,
        'playedAt': playedAt.toIso8601String(),
      };

  factory MatchHistoryRecord.fromJson(Map<String, dynamic> json) {
    return MatchHistoryRecord(
      matchId: json['matchId'] as String,
      player1Name: json['player1Name'] as String,
      player2Name: json['player2Name'] as String,
      firstInningsRuns: json['firstInningsRuns'] as int,
      secondInningsRuns: json['secondInningsRuns'] as int,
      winnerName: json['winnerName'] as String?,
      resultSummary: json['resultSummary'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
    );
  }
}

class MatchHistoryRepository {
  static const String _key = 'odd_or_even_match_history';

  Future<List<MatchHistoryRecord>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_key) ?? [];
      return rawList
          .map((item) => MatchHistoryRecord.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMatchRecord(GameMatchState match) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = prefs.getStringList(_key) ?? [];

      final winnerName = match.winnerId != null
          ? match.getPlayerById(match.winnerId!).name
          : null;

      final summary = match.resultType?.description ?? 'Match Complete';

      final record = MatchHistoryRecord(
        matchId: match.matchId,
        player1Name: match.player1.name,
        player2Name: match.player2.name,
        firstInningsRuns: match.firstInningsRuns,
        secondInningsRuns: match.currentInningsRuns,
        winnerName: winnerName,
        resultSummary: summary,
        playedAt: DateTime.now(),
      );

      currentList.insert(0, jsonEncode(record.toJson()));
      // Keep up to 50 recent records
      if (currentList.length > 50) {
        currentList.removeLast();
      }

      await prefs.setStringList(_key, currentList);
    } catch (_) {}
  }
}

final matchHistoryRepositoryProvider = Provider<MatchHistoryRepository>((ref) {
  return MatchHistoryRepository();
});

final matchHistoryListProvider =
    FutureProvider<List<MatchHistoryRecord>>((ref) async {
  final repo = ref.watch(matchHistoryRepositoryProvider);
  return repo.getHistory();
});
