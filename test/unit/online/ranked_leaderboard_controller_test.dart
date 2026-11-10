import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/online/data/online_ranked_repository.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_exceptions.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_leaderboard_entry.dart';
import 'package:odd_or_even/features/online/presentation/controllers/ranked_leaderboard_controller.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';

class MockLeaderboardRepository extends OnlineRankedRepository {
  String? authenticatedUid = 'user-p1';
  List<RankedLeaderboardEntry> leaderboardEntries = [];
  int getLeaderboardCallCount = 0;
  Exception? throwOnGetLeaderboard;

  MockLeaderboardRepository() : super();

  @override
  String? get currentUserId => authenticatedUid;

  @override
  Future<String?> ensureAuthenticatedUser() async => authenticatedUid;

  @override
  Future<List<RankedLeaderboardEntry>> getLeaderboard({
    int limit = 100,
    int offset = 0,
  }) async {
    getLeaderboardCallCount++;
    if (throwOnGetLeaderboard != null) throw throwOnGetLeaderboard!;
    return leaderboardEntries;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLeaderboardRepository mockRepo;
  late List<RankedLeaderboardEntry> sampleEntries;

  setUp(() {
    mockRepo = MockLeaderboardRepository();

    sampleEntries = const [
      RankedLeaderboardEntry(
        userId: 'user-gm1',
        displayName: 'Champion Alex',
        avatarIndex: 0,
        tier: RankTier.grandMaster,
        stars: 0,
        mmr: 2150,
        winStreak: 8,
        totalRankedWins: 45,
        totalRankedMatches: 50,
        leaderboardRank: 1,
      ),
      RankedLeaderboardEntry(
        userId: 'user-p1',
        displayName: 'Player One',
        avatarIndex: 1,
        tier: RankTier.gold,
        division: RankDivision.II,
        stars: 2,
        mmr: 1350,
        winStreak: 3,
        totalRankedWins: 18,
        totalRankedMatches: 25,
        leaderboardRank: 2,
      ),
      RankedLeaderboardEntry(
        userId: 'user-s1',
        displayName: 'Silver Striker',
        avatarIndex: 2,
        tier: RankTier.silver,
        division: RankDivision.I,
        stars: 1,
        mmr: 1180,
        winStreak: 0,
        totalRankedWins: 10,
        totalRankedMatches: 20,
        leaderboardRank: 3,
      ),
    ];
  });

  group('RankedLeaderboardNotifier - Unit Tests', () {
    test('Initial loading fetches entries and identifies current user', () async {
      mockRepo.leaderboardEntries = sampleEntries;
      final notifier = RankedLeaderboardNotifier(mockRepo);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.entries.length, 3);
      expect(notifier.state.grandMasterCount, 1);
      expect(notifier.state.currentUserId, 'user-p1');
      expect(notifier.state.currentUserEntry?.displayName, 'Player One');
      expect(notifier.state.currentUserEntry?.leaderboardRank, 2);
      expect(notifier.state.errorMessage, isNull);
    });

    test('Computes grandMasterCount accurately', () async {
      mockRepo.leaderboardEntries = [
        const RankedLeaderboardEntry(
          userId: 'gm-1',
          displayName: 'GM One',
          tier: RankTier.grandMaster,
          leaderboardRank: 1,
        ),
        const RankedLeaderboardEntry(
          userId: 'gm-2',
          displayName: 'GM Two',
          tier: RankTier.grandMaster,
          leaderboardRank: 2,
        ),
        const RankedLeaderboardEntry(
          userId: 'm-1',
          displayName: 'Master One',
          tier: RankTier.master,
          leaderboardRank: 3,
        ),
      ];

      final notifier = RankedLeaderboardNotifier(mockRepo);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.grandMasterCount, 2);
    });

    test('Handles empty leaderboard when no ranked matches exist', () async {
      mockRepo.leaderboardEntries = [];
      final notifier = RankedLeaderboardNotifier(mockRepo);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.entries, isEmpty);
      expect(notifier.state.currentUserEntry, isNull);
      expect(notifier.state.errorMessage, isNull);
    });

    test('Refresh operation updates data without clearing previous entries', () async {
      mockRepo.leaderboardEntries = sampleEntries;
      final notifier = RankedLeaderboardNotifier(mockRepo);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.entries.length, 3);

      // Simulate refresh with additional entry
      mockRepo.leaderboardEntries = [
        ...sampleEntries,
        const RankedLeaderboardEntry(
          userId: 'user-new',
          displayName: 'New Challenger',
          tier: RankTier.bronze,
          division: RankDivision.III,
          leaderboardRank: 4,
        ),
      ];

      final refreshFuture = notifier.loadLeaderboard(isRefresh: true);
      expect(notifier.state.isRefreshing, isTrue);
      // Previous entries are preserved during refresh
      expect(notifier.state.entries.length, 3);

      await refreshFuture;

      expect(notifier.state.isRefreshing, isFalse);
      expect(notifier.state.entries.length, 4);
    });

    test('Catches error and presents friendly error message', () async {
      mockRepo.throwOnGetLeaderboard = const RankedException(
        code: RankedErrorCode.networkError,
        message: 'PostgreSQL connection timeout',
      );

      final notifier = RankedLeaderboardNotifier(mockRepo);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.entries, isEmpty);
      expect(notifier.state.errorMessage, contains('PostgreSQL connection timeout'));
    });

    test('Prevents duplicate concurrent requests', () async {
      mockRepo.leaderboardEntries = sampleEntries;
      final notifier = RankedLeaderboardNotifier(mockRepo);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(mockRepo.getLeaderboardCallCount, 1);

      // Trigger concurrent loads
      notifier.loadLeaderboard(isRefresh: true);
      notifier.loadLeaderboard(isRefresh: true);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 1 initial load + 1 refresh (2nd ignored)
      expect(mockRepo.getLeaderboardCallCount, 2);
    });
  });
}
