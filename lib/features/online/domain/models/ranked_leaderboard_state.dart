import 'ranked_leaderboard_entry.dart';

/// Immutable state for the competitive Online Ranked public leaderboard.
class RankedLeaderboardState {
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final List<RankedLeaderboardEntry> entries;
  final String? currentUserId;
  final RankedLeaderboardEntry? currentUserEntry;

  const RankedLeaderboardState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.errorMessage,
    this.entries = const [],
    this.currentUserId,
    this.currentUserEntry,
  });

  /// Factory for initial uninitialized state.
  factory RankedLeaderboardState.initial() => const RankedLeaderboardState();

  RankedLeaderboardState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    List<RankedLeaderboardEntry>? entries,
    String? currentUserId,
    RankedLeaderboardEntry? currentUserEntry,
    bool clearErrorMessage = false,
  }) {
    return RankedLeaderboardState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      entries: entries ?? this.entries,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserEntry: currentUserEntry ?? this.currentUserEntry,
    );
  }

  /// Total count of Grand Master players in the current leaderboard.
  int get grandMasterCount =>
      entries.where((e) => e.tier.displayName == 'Grand Master').length;
}
