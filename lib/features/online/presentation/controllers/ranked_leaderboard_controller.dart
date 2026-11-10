import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/online_ranked_repository.dart';
import '../../domain/models/ranked_exceptions.dart';
import '../../domain/models/ranked_leaderboard_entry.dart';
import '../../domain/models/ranked_leaderboard_state.dart';

/// StateNotifier managing public competitive leaderboard fetching,
/// authenticated user entry identification, and refresh operations.
class RankedLeaderboardNotifier extends StateNotifier<RankedLeaderboardState> {
  final OnlineRankedRepository _repo;

  RankedLeaderboardNotifier(this._repo) : super(RankedLeaderboardState.initial()) {
    loadLeaderboard();
  }

  /// Fetches top leaderboard entries from PostgreSQL view or RPC.
  Future<void> loadLeaderboard({bool isRefresh = false}) async {
    if (state.isRefreshing) return;
    if (state.isLoading && isRefresh) return;

    if (isRefresh) {
      state = state.copyWith(isRefreshing: true, clearErrorMessage: true);
    } else {
      state = state.copyWith(isLoading: true, clearErrorMessage: true);
    }

    try {
      final uid = _repo.currentUserId ?? await _repo.ensureAuthenticatedUser();
      final entries = await _repo.getLeaderboard(limit: 100, offset: 0);

      RankedLeaderboardEntry? userEntry;
      if (uid != null) {
        for (final entry in entries) {
          if (entry.userId == uid) {
            userEntry = entry;
            break;
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        entries: entries,
        currentUserId: uid,
        currentUserEntry: userEntry,
      );
    } catch (e) {
      final msg = e is RankedException
          ? e.message
          : 'Unable to load leaderboard. Please check connection and try again.';
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: msg,
      );
    }
  }
}

/// Riverpod provider for the competitive online leaderboard.
final rankedLeaderboardProvider =
    StateNotifierProvider.autoDispose<RankedLeaderboardNotifier, RankedLeaderboardState>((ref) {
  final repo = ref.watch(onlineRankedRepositoryProvider);
  return RankedLeaderboardNotifier(repo);
});
