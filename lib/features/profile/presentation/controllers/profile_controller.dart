import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../history/data/match_history_repository.dart';
import '../../../online/data/online_ranked_repository.dart';
import '../../../online/data/supabase_match_repository.dart';
import '../../../online/domain/models/online_player_rank.dart';
import '../../../progression/data/local_progression_repo.dart';
import '../../../progression/domain/models/career_stats.dart';
import '../../../progression/domain/models/rank_tier.dart';
import '../../../progression/domain/models/xp_progress.dart';

class ProfileProgressionState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String displayName;
  final int avatarIndex;
  final XpProgress xpProgress;
  final int dailyXpEarned;
  final VsComputerRankState vsRankState;
  final Map<String, ModeCareerStats> modeStatsMap;
  final String selectedStatsMode; // 'all', 'vs_computer_ranked', 'casual_vs_computer', 'pass_and_play', 'online'
  final List<MatchHistoryRecord> matchHistory;
  final Map<String, dynamic>? onlineProfile;
  final bool isOnlineConfigured;
  final OnlinePlayerRank? onlineRank;
  final OnlineRankedStats? onlineStats;

  const ProfileProgressionState({
    required this.isLoading,
    this.isSaving = false,
    this.errorMessage,
    required this.displayName,
    required this.avatarIndex,
    required this.xpProgress,
    required this.dailyXpEarned,
    required this.vsRankState,
    required this.modeStatsMap,
    this.selectedStatsMode = 'all',
    this.matchHistory = const [],
    this.onlineProfile,
    this.isOnlineConfigured = false,
    this.onlineRank,
    this.onlineStats,
  });

  /// Currently active stats object based on [selectedStatsMode].
  ModeCareerStats get currentStats =>
      modeStatsMap[selectedStatsMode] ?? const ModeCareerStats();

  /// Authoritative Online Ranked level derived from canonical XpEconomy.
  int get onlineLevel =>
      XpEconomy.calculateProgress(onlineRank?.totalXp ?? 0).level;

  ProfileProgressionState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? displayName,
    int? avatarIndex,
    XpProgress? xpProgress,
    int? dailyXpEarned,
    VsComputerRankState? vsRankState,
    Map<String, ModeCareerStats>? modeStatsMap,
    String? selectedStatsMode,
    List<MatchHistoryRecord>? matchHistory,
    Map<String, dynamic>? onlineProfile,
    bool? isOnlineConfigured,
    OnlinePlayerRank? onlineRank,
    OnlineRankedStats? onlineStats,
  }) {
    return ProfileProgressionState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      displayName: displayName ?? this.displayName,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      xpProgress: xpProgress ?? this.xpProgress,
      dailyXpEarned: dailyXpEarned ?? this.dailyXpEarned,
      vsRankState: vsRankState ?? this.vsRankState,
      modeStatsMap: modeStatsMap ?? this.modeStatsMap,
      selectedStatsMode: selectedStatsMode ?? this.selectedStatsMode,
      matchHistory: matchHistory ?? this.matchHistory,
      onlineProfile: onlineProfile ?? this.onlineProfile,
      isOnlineConfigured: isOnlineConfigured ?? this.isOnlineConfigured,
      onlineRank: onlineRank ?? this.onlineRank,
      onlineStats: onlineStats ?? this.onlineStats,
    );
  }
}

class ProfileProgressionNotifier extends StateNotifier<ProfileProgressionState> {
  final LocalProgressionRepository _progressionRepo;
  final MatchHistoryRepository _historyRepo;
  final SupabaseMatchRepository _supabaseRepo;
  final OnlineRankedRepository _onlineRankedRepo;

  ProfileProgressionNotifier(
    this._progressionRepo,
    this._historyRepo,
    this._supabaseRepo, [
    OnlineRankedRepository? onlineRankedRepo,
  ])  : _onlineRankedRepo = onlineRankedRepo ?? OnlineRankedRepository(),
        super(
          ProfileProgressionState(
            isLoading: false,
            displayName: 'Player 1',
            avatarIndex: 0,
            xpProgress: XpEconomy.calculateProgress(0),
            dailyXpEarned: 0,
            vsRankState: VsComputerRankState.initial(),
            modeStatsMap: const {
              'all': ModeCareerStats(),
              'vs_computer_ranked': ModeCareerStats(),
              'casual_vs_computer': ModeCareerStats(),
              'pass_and_play': ModeCareerStats(),
              'online': ModeCareerStats(),
            },
          ),
        ) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final name = await _progressionRepo.getLocalDisplayName();
      final avatar = await _progressionRepo.getLocalAvatarIndex();
      final xp = await _progressionRepo.getXpProgress();
      final dailyXp = await _progressionRepo.getDailyXpEarned();
      final rank = await _progressionRepo.getVsComputerRankState();
      final statsMap = await _progressionRepo.getAllModeStats();
      final history = await _historyRepo.getHistory();

      Map<String, dynamic>? onlineProf;
      final isConfigured = _supabaseRepo.isConfigured;
      if (isConfigured) {
        final uid = await _supabaseRepo.ensureAuthenticatedUser();
        if (uid != null) {
          onlineProf = await _supabaseRepo.getProfile(uid);
        }
      }

      OnlinePlayerRank? onlineRank;
      OnlineRankedStats? onlineStats;
      if (_onlineRankedRepo.isConfigured) {
        final uid = await _onlineRankedRepo.ensureAuthenticatedUser();
        if (uid != null) {
          try {
            onlineRank = await _onlineRankedRepo.getPlayerRank(uid);
            onlineStats = await _onlineRankedRepo.getPlayerStats(uid);
          } catch (e) {
            debugPrint('ProfileProgressionNotifier: Error loading online rank: $e');
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        displayName: (onlineProf?['display_name'] as String?) ?? name,
        avatarIndex: (onlineProf?['avatar_index'] as int?) ?? avatar,
        xpProgress: xp,
        dailyXpEarned: dailyXp,
        vsRankState: rank,
        modeStatsMap: statsMap,
        matchHistory: history,
        onlineProfile: onlineProf,
        isOnlineConfigured: isConfigured,
        onlineRank: onlineRank,
        onlineStats: onlineStats,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load profile data: $e',
      );
    }
  }

  void setStatsMode(String mode) {
    state = state.copyWith(selectedStatsMode: mode);
  }

  void updateAvatarIndex(int index) {
    state = state.copyWith(avatarIndex: index);
  }

  Future<bool> saveProfile(String displayName, int avatarIndex) async {
    final cleanName = displayName.trim().isEmpty ? 'Player 1' : displayName.trim();
    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      await _progressionRepo.saveLocalDisplayName(cleanName);
      await _progressionRepo.saveLocalAvatarIndex(avatarIndex);

      if (_supabaseRepo.isConfigured) {
        await _supabaseRepo.updateProfile(
          displayName: cleanName,
          avatarIndex: avatarIndex,
        );
      }

      state = state.copyWith(
        isSaving: false,
        displayName: cleanName,
        avatarIndex: avatarIndex,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save profile: $e',
      );
      return false;
    }
  }
}

final profileProgressionProvider =
    StateNotifierProvider<ProfileProgressionNotifier, ProfileProgressionState>((ref) {
  final progressionRepo = ref.watch(localProgressionRepositoryProvider);
  final historyRepo = ref.watch(matchHistoryRepositoryProvider);
  final supabaseRepo = ref.watch(supabaseMatchRepositoryProvider);
  final onlineRankedRepo = ref.watch(onlineRankedRepositoryProvider);
  return ProfileProgressionNotifier(
    progressionRepo,
    historyRepo,
    supabaseRepo,
    onlineRankedRepo,
  );
});
