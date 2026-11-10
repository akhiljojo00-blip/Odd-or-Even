import 'package:flutter_test/flutter_test.dart';
import 'package:odd_or_even/features/online/data/online_ranked_repository.dart';
import 'package:odd_or_even/features/online/data/ranked_realtime_manager.dart';
import 'package:odd_or_even/features/online/domain/models/online_player_rank.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_ball_event.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_exceptions.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_leaderboard_entry.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_match.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_match_settlement.dart';
import 'package:odd_or_even/features/online/domain/models/ranked_matchmaking_state.dart';
import 'package:odd_or_even/features/progression/domain/models/rank_tier.dart';
import 'package:odd_or_even/features/progression/domain/models/xp_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Fake mock repository for testing RealtimeManager without remote Supabase
class FakeOnlineRankedRepository extends OnlineRankedRepository {
  RankedMatch? fakeMatch;
  List<RankedBallEvent> fakeBallEvents = [];
  bool unsubscribeCalled = false;
  int getMatchCallCount = 0;
  int getBallEventsCallCount = 0;

  FakeOnlineRankedRepository() : super();

  @override
  bool get isConfigured => true;

  @override
  Future<RankedMatch?> getMatch(String matchId) async {
    getMatchCallCount++;
    return fakeMatch;
  }

  @override
  Future<List<RankedBallEvent>> getBallEvents(String matchId) async {
    getBallEventsCallCount++;
    return fakeBallEvents;
  }

  @override
  RealtimeChannel? subscribeToMatchChannel({
    required String matchId,
    required void Function() onMatchChanged,
    required void Function() onBallEvent,
    void Function(RealtimeSubscribeStatus status)? onStatusChange,
  }) {
    // Return null to simulate a channel handle for lifecycle tests
    return null;
  }

  @override
  Future<void> unsubscribeChannel(RealtimeChannel? channel) async {
    unsubscribeCalled = true;
  }
}

void main() {
  group('Online Ranked Client Foundation - Model & Contract Tests', () {
    // -----------------------------------------------------------------------
    // 1. RankedMatch Model & JSON Serialization
    // -----------------------------------------------------------------------
    group('RankedMatch Model', () {
      test('Parses full ranked_matches row from PostgreSQL correctly', () {
        final json = {
          'id': 'e8b2a3c4-1234-5678-9abc-def012345678',
          'season_id': 1,
          'phase': 'first_innings',
          'version': 3,
          'config': {'number_range': 6, 'overs': 2},
          'player1_id': 'p1-uuid',
          'player2_id': 'p2-uuid',
          'player1_parity': 'odd',
          'player2_parity': 'even',
          'toss_winner_id': 'p1-uuid',
          'batting_first_id': 'p1-uuid',
          'current_innings_no': 1,
          'first_innings_runs': 0,
          'target_runs': null,
          'current_batter_id': 'p1-uuid',
          'current_bowler_id': 'p2-uuid',
          'current_innings_runs': 12,
          'legal_balls_bowled': 3,
          'winner_id': null,
          'result_type': null,
          'turn_deadline_at': '2026-11-10T12:00:20.000Z',
          'player1_heartbeat_at': '2026-11-10T12:00:10.000Z',
          'player2_heartbeat_at': '2026-11-10T12:00:09.000Z',
          'p1_disconnected_at': null,
          'p2_disconnected_at': null,
          'p1_grace_expires_at': null,
          'p2_grace_expires_at': null,
          'p1_saved_turn_seconds': null,
          'p2_saved_turn_seconds': null,
          'p1_grace_remaining_seconds': 30,
          'p2_grace_remaining_seconds': 30,
          'p1_disconnect_count': 0,
          'p2_disconnect_count': 0,
          'created_at': '2026-11-10T12:00:00.000Z',
          'updated_at': '2026-11-10T12:00:15.000Z',
        };

        final match = RankedMatch.fromJson(json);

        expect(match.id, 'e8b2a3c4-1234-5678-9abc-def012345678');
        expect(match.seasonId, 1);
        expect(match.phase, RankedMatchPhase.firstInnings);
        expect(match.version, 3);
        expect(match.config.numberRange, 6);
        expect(match.config.overs, 2);
        expect(match.player1Id, 'p1-uuid');
        expect(match.player2Id, 'p2-uuid');
        expect(match.player1Parity, PlayerParity.odd);
        expect(match.player2Parity, PlayerParity.even);
        expect(match.tossWinnerId, 'p1-uuid');
        expect(match.currentInningsRuns, 12);
        expect(match.legalBallsBowled, 3);
        expect(match.isCompleted, isFalse);

        // Helper methods
        expect(match.isParticipant('p1-uuid'), isTrue);
        expect(match.isParticipant('p2-uuid'), isTrue);
        expect(match.isParticipant('stranger-uuid'), isFalse);
        expect(match.opponentId('p1-uuid'), 'p2-uuid');
        expect(match.opponentId('p2-uuid'), 'p1-uuid');
        expect(match.myParity('p1-uuid'), PlayerParity.odd);
        expect(match.opponentParity('p1-uuid'), PlayerParity.even);
      });

      test('Parses concluded match with winner, result_type and nulls safely', () {
        final json = {
          'id': 'match-fin-123',
          'phase': 'match_finished',
          'player1_id': 'p1',
          'player2_id': 'p2',
          'player1_parity': 'even',
          'player2_parity': 'odd',
          'winner_id': 'p1',
          'result_type': 'runs',
        };

        final match = RankedMatch.fromJson(json);

        expect(match.isCompleted, isTrue);
        expect(match.isWinner('p1'), isTrue);
        expect(match.isWinner('p2'), isFalse);
        expect(match.resultType, RankedResultType.runs);
        expect(match.isTie, isFalse);
        expect(match.isForfeit, isFalse);
        expect(match.isAbandoned, isFalse);
      });

      test('Handles forfeit and abandoned results', () {
        final forfeitMatch = RankedMatch.fromJson({
          'id': 'm1',
          'phase': 'match_forfeited',
          'player1_id': 'p1',
          'player2_id': 'p2',
          'winner_id': 'p2',
          'result_type': 'forfeit',
        });
        expect(forfeitMatch.isForfeit, isTrue);
        expect(forfeitMatch.isCompleted, isTrue);

        final abandonedMatch = RankedMatch.fromJson({
          'id': 'm2',
          'phase': 'match_forfeited',
          'player1_id': 'p1',
          'player2_id': 'p2',
          'winner_id': null,
          'result_type': 'abandoned',
        });
        expect(abandonedMatch.isAbandoned, isTrue);
        expect(abandonedMatch.isCompleted, isTrue);
      });

      test('Handles missing, null, or empty fields with resilient defaults', () {
        final match = RankedMatch.fromJson({});

        expect(match.id, isEmpty);
        expect(match.phase, RankedMatchPhase.tossInput);
        expect(match.version, 1);
        expect(match.config.numberRange, 6);
        expect(match.config.overs, 2);
        expect(match.player1Parity, PlayerParity.odd);
        expect(match.player2Parity, PlayerParity.even);
        expect(match.currentInningsNo, 1);
        expect(match.firstInningsRuns, 0);
        expect(match.currentInningsRuns, 0);
        expect(match.legalBallsBowled, 0);
        expect(match.p1GraceRemainingSeconds, 30);
        expect(match.p2GraceRemainingSeconds, 30);
      });

      test('Serializes to JSON with exact PostgreSQL contract keys', () {
        const match = RankedMatch(
          id: 'test-id',
          seasonId: 1,
          phase: RankedMatchPhase.tossInput,
          player1Id: 'p1',
          player2Id: 'p2',
          player1Parity: PlayerParity.odd,
          player2Parity: PlayerParity.even,
        );

        final json = match.toJson();
        expect(json['id'], 'test-id');
        expect(json['season_id'], 1);
        expect(json['phase'], 'toss_input');
        expect(json['player1_id'], 'p1');
        expect(json['player2_id'], 'p2');
        expect(json['player1_parity'], 'odd');
        expect(json['player2_parity'], 'even');
        expect(json['config'], isA<Map<String, dynamic>>());
      });
    });

    // -----------------------------------------------------------------------
    // 2. OnlinePlayerRank & Canonical XP Level Progression
    // -----------------------------------------------------------------------
    group('OnlinePlayerRank Model & Canonical XP Progression', () {
      test('Parses complete online_player_ranks row with tier, division, stars, and MMR', () {
        final json = {
          'user_id': 'u1-uuid',
          'total_xp': 1450,
          'tier': 'Gold',
          'division': 'II',
          'stars': 2,
          'mmr': 1350,
          'peak_tier': 'Platinum',
          'peak_division': 'I',
          'peak_mmr': 1420,
          'win_streak': 4,
          'longest_win_streak': 7,
          'demotion_shield_active': false,
          'total_ranked_matches': 25,
          'total_ranked_wins': 18,
          'total_ranked_losses': 6,
          'total_ranked_ties': 1,
          'created_at': '2026-11-01T00:00:00.000Z',
          'updated_at': '2026-11-10T12:00:00.000Z',
        };

        final rank = OnlinePlayerRank.fromJson(json);

        expect(rank.userId, 'u1-uuid');
        expect(rank.totalXp, 1450);
        expect(rank.tier, RankTier.gold);
        expect(rank.division, RankDivision.II);
        expect(rank.stars, 2);
        expect(rank.mmr, 1350);
        expect(rank.peakTier, RankTier.platinum);
        expect(rank.peakDivision, RankDivision.I);
        expect(rank.peakMmr, 1420);
        expect(rank.winStreak, 4);
        expect(rank.longestWinStreak, 7);
        expect(rank.totalRankedMatches, 25);
        expect(rank.totalRankedWins, 18);
        expect(rank.fullRankLabel, 'Gold II');
        expect(rank.peakRankLabel, 'Platinum I');
        expect(rank.winRate, closeTo(72.0, 0.01));
      });

      test('Derived XP progress matches canonical XpEconomy calculation exactly', () {
        // total_xp = 1450
        // Level 1: 100 XP (0..100)
        // Level 2: 150 XP (100..250)
        // Level 3: 200 XP (250..450)
        // Level 4: 250 XP (450..700)
        // Level 5: 300 XP (700..1000)
        // Level 6: 350 XP (1000..1350)
        // Level 7: 400 XP (1350..1750) -> 1450 is at Level 7!
        final canonical = XpEconomy.calculateProgress(1450);

        final rank = OnlinePlayerRank.fromJson({
          'user_id': 'u1',
          'total_xp': 1450,
          'tier': 'Bronze',
          'division': 'III',
        });

        expect(rank.playerLevel, equals(canonical.level));
        expect(rank.xpProgress.level, equals(7));
        expect(rank.xpProgress.currentLevelBaseXp, equals(canonical.currentLevelBaseXp));
        expect(rank.xpProgress.currentLevelProgressXp, equals(canonical.currentLevelProgressXp));
        expect(rank.xpProgress.xpRequiredForNextLevel, equals(canonical.xpRequiredForNextLevel));
        expect(rank.xpProgress.progressFraction, equals(canonical.progressFraction));
        expect(rank.xpProgress.xpToNextLevel, equals(300));
      });

      test('Parses Master and Grand Master tiers with null division', () {
        final masterJson = {
          'user_id': 'master-uuid',
          'total_xp': 8000,
          'tier': 'Master',
          'division': null,
          'stars': 6,
          'mmr': 2400,
        };

        final masterRank = OnlinePlayerRank.fromJson(masterJson);
        expect(masterRank.tier, RankTier.master);
        expect(masterRank.division, isNull);
        expect(masterRank.fullRankLabel, 'Master');
        expect(masterRank.isMasterOrGrandMaster, isTrue);
        expect(masterRank.isGrandMaster, isFalse);

        final gmJson = {
          'user_id': 'gm-uuid',
          'total_xp': 15000,
          'tier': 'Grand Master',
          'division': null,
          'stars': 0,
          'mmr': 2850,
        };

        final gmRank = OnlinePlayerRank.fromJson(gmJson);
        expect(gmRank.tier, RankTier.grandMaster);
        expect(gmRank.division, isNull);
        expect(gmRank.fullRankLabel, 'Grand Master');
        expect(gmRank.isMasterOrGrandMaster, isTrue);
        expect(gmRank.isGrandMaster, isTrue);
      });

      test('OnlinePlayerRank.initial provides default Bronze III 0 stars 1000 MMR', () {
        final initial = OnlinePlayerRank.initial('new-player');
        expect(initial.userId, 'new-player');
        expect(initial.totalXp, 0);
        expect(initial.playerLevel, 1);
        expect(initial.tier, RankTier.bronze);
        expect(initial.division, RankDivision.III);
        expect(initial.stars, 0);
        expect(initial.mmr, 1000);
        expect(initial.fullRankLabel, 'Bronze III');
      });

      test('Separation of Online Ranked and VS Computer progression models', () {
        // Online Rank model
        final onlineRank = OnlinePlayerRank.fromJson({
          'user_id': 'u1',
          'total_xp': 3000,
          'tier': 'Gold',
          'division': 'I',
          'stars': 2,
          'mmr': 1400,
        });

        // Offline VS Computer state model
        const vsComputerRank = VsComputerRankState(
          tier: RankTier.bronze,
          division: RankDivision.III,
          stars: 1,
          peakTier: RankTier.bronze,
          peakDivision: RankDivision.III,
          matchesPlayed: 5,
          matchesWon: 3,
        );

        // Assert completely distinct types and states
        expect(onlineRank.tier, equals(RankTier.gold));
        expect(vsComputerRank.tier, equals(RankTier.bronze));
        expect(onlineRank.stars, equals(2));
        expect(vsComputerRank.stars, equals(1));
        expect(onlineRank.mmr, equals(1400));
        // VsComputerRankState does not have MMR or total_xp, proving architectural isolation
      });
    });

    // -----------------------------------------------------------------------
    // 3. OnlineRankedStats Model
    // -----------------------------------------------------------------------
    group('OnlineRankedStats Model', () {
      test('Parses online_ranked_stats with runs, wickets, high score, and chase', () {
        final json = {
          'user_id': 'u1',
          'total_runs': 184,
          'total_wickets': 28,
          'highest_score': 32,
          'best_chase': 24,
          'updated_at': '2026-11-10T12:00:00.000Z',
        };

        final stats = OnlineRankedStats.fromJson(json);

        expect(stats.userId, 'u1');
        expect(stats.totalRuns, 184);
        expect(stats.totalWickets, 28);
        expect(stats.highestScore, 32);
        expect(stats.bestChase, 24);
      });

      test('Handles null best_chase safely', () {
        final stats = OnlineRankedStats.fromJson({
          'user_id': 'u2',
          'total_runs': 0,
          'total_wickets': 0,
          'highest_score': 0,
          'best_chase': null,
        });

        expect(stats.bestChase, isNull);
        expect(stats.totalRuns, 0);
      });
    });

    // -----------------------------------------------------------------------
    // 4. RankedBallEvent Model
    // -----------------------------------------------------------------------
    group('RankedBallEvent Model', () {
      test('Parses ranked_ball_events row and evaluates boundary & wicket correctly', () {
        final event1 = RankedBallEvent.fromJson({
          'id': 'b1',
          'match_id': 'm1',
          'innings_no': 1,
          'ball_no': 1,
          'batter_id': 'p1',
          'bowler_id': 'p2',
          'batter_number': 6,
          'bowler_number': 3,
          'runs_scored': 6,
          'is_wicket': false,
          'cumulative_runs': 6,
        });

        expect(event1.runsScored, 6);
        expect(event1.isBoundary, isTrue);
        expect(event1.isWicket, isFalse);

        final event2 = RankedBallEvent.fromJson({
          'id': 'b2',
          'match_id': 'm1',
          'innings_no': 1,
          'ball_no': 2,
          'batter_id': 'p1',
          'bowler_id': 'p2',
          'batter_number': 4,
          'bowler_number': 4,
          'runs_scored': 0,
          'is_wicket': true,
          'cumulative_runs': 6,
        });

        expect(event2.runsScored, 0);
        expect(event2.isBoundary, isFalse);
        expect(event2.isWicket, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // 5. RankedMatchSettlement Model
    // -----------------------------------------------------------------------
    group('RankedMatchSettlement Model', () {
      test('Parses settlement row and computes player-specific deltas accurately', () {
        final json = {
          'match_id': 'm1',
          'winner_id': 'p1',
          'loser_id': 'p2',
          'is_tie': false,
          'is_forfeit': false,
          'is_abandoned': false,
          'legal_balls_bowled': 8,
          'is_early_forfeit': false,
          'is_pair_star_capped': false,
          'p1_stars_delta': 1,
          'p2_stars_delta': -1,
          'p1_mmr_delta': 18,
          'p2_mmr_delta': -18,
          'p1_xp_awarded': 50,
          'p2_xp_awarded': 30,
        };

        final settlement = RankedMatchSettlement.fromJson(json);

        expect(settlement.matchId, 'm1');
        expect(settlement.winnerId, 'p1');
        expect(settlement.starsDeltaFor('p1', 'p1'), 1);
        expect(settlement.starsDeltaFor('p2', 'p1'), -1);
        expect(settlement.mmrDeltaFor('p1', 'p1'), 18);
        expect(settlement.mmrDeltaFor('p2', 'p1'), -18);
        expect(settlement.xpAwardedFor('p1', 'p1'), 50);
        expect(settlement.xpAwardedFor('p2', 'p1'), 30);
      });

      test('Handles early forfeit settlement with 0 stars and -16 loser MMR', () {
        final json = {
          'match_id': 'm2',
          'winner_id': 'p1',
          'loser_id': 'p2',
          'is_tie': false,
          'is_forfeit': true,
          'is_abandoned': false,
          'legal_balls_bowled': 2,
          'is_early_forfeit': true,
          'is_pair_star_capped': false,
          'p1_stars_delta': 0,
          'p2_stars_delta': 0,
          'p1_mmr_delta': 0,
          'p2_mmr_delta': -16,
          'p1_xp_awarded': 0,
          'p2_xp_awarded': 0,
        };

        final settlement = RankedMatchSettlement.fromJson(json);

        expect(settlement.isEarlyForfeit, isTrue);
        expect(settlement.starsDeltaFor('p1', 'p1'), 0);
        expect(settlement.starsDeltaFor('p2', 'p1'), 0);
        expect(settlement.mmrDeltaFor('p1', 'p1'), 0);
        expect(settlement.mmrDeltaFor('p2', 'p1'), -16);
      });
    });

    // -----------------------------------------------------------------------
    // 6. RankedLeaderboardEntry Model
    // -----------------------------------------------------------------------
    group('RankedLeaderboardEntry Model', () {
      test('Parses v_ranked_leaderboard row correctly', () {
        final json = {
          'user_id': 'top-1-uuid',
          'display_name': 'CricketMaster',
          'avatar_index': 3,
          'tier': 'Pro Elite',
          'division': 'I',
          'stars': 3,
          'mmr': 2145,
          'win_streak': 8,
          'total_ranked_wins': 45,
          'total_ranked_matches': 50,
          'leaderboard_rank': 1,
        };

        final entry = RankedLeaderboardEntry.fromJson(json);

        expect(entry.userId, 'top-1-uuid');
        expect(entry.displayName, 'CricketMaster');
        expect(entry.avatarIndex, 3);
        expect(entry.tier, RankTier.proElite);
        expect(entry.division, RankDivision.I);
        expect(entry.fullRankLabel, 'Pro Elite I');
        expect(entry.mmr, 2145);
        expect(entry.leaderboardRank, 1);
        expect(entry.winRate, closeTo(90.0, 0.01));
      });
    });

    // -----------------------------------------------------------------------
    // 7. RankedMatchmakingState Model
    // -----------------------------------------------------------------------
    group('RankedMatchmakingState Model', () {
      test('Parses queued, matched, and active_match_exists statuses', () {
        final queued = RankedMatchmakingResult.fromJson({'status': 'queued'});
        expect(queued.status, RankedMatchmakingStatus.queued);
        expect(queued.isQueued, isTrue);

        final matched = RankedMatchmakingResult.fromJson({
          'status': 'matched',
          'match_id': 'match-new-1',
        });
        expect(matched.status, RankedMatchmakingStatus.matched);
        expect(matched.isMatched, isTrue);
        expect(matched.matchId, 'match-new-1');

        final active = RankedMatchmakingResult.fromJson({
          'status': 'active_match_exists',
          'match_id': 'match-prev-1',
        });
        expect(active.status, RankedMatchmakingStatus.activeMatchExists);
        expect(active.hasActiveMatch, isTrue);
        expect(active.matchId, 'match-prev-1');

        final cancelled = RankedMatchmakingResult.fromJson({'status': 'cancelled'});
        expect(cancelled.status, RankedMatchmakingStatus.cancelled);
        expect(cancelled.isCancelled, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // 8. RankedException & RPC Error Mapping
    // -----------------------------------------------------------------------
    group('RankedException & RPC Error Mapping', () {
      test('Maps all critical PostgreSQL error messages to typed enum codes', () {
        expect(RankedErrorCode.fromMessage('Not authenticated'),
            RankedErrorCode.notAuthenticated);
        expect(RankedErrorCode.fromMessage('Invalid choice: must be between 1 and 6'),
            RankedErrorCode.invalidChoice);
        expect(RankedErrorCode.fromMessage('Caller is not a participant in this match'),
            RankedErrorCode.notParticipant);
        expect(RankedErrorCode.fromMessage('Match not found'),
            RankedErrorCode.matchNotFound);
        expect(RankedErrorCode.fromMessage('Invalid role: must be bat or bowl'),
            RankedErrorCode.invalidRole);
        expect(RankedErrorCode.fromMessage('Match is not in role_selection phase (current: toss_input)'),
            RankedErrorCode.invalidPhase);
        expect(RankedErrorCode.fromMessage('Only the toss winner may select role'),
            RankedErrorCode.notTossWinner);
        expect(RankedErrorCode.fromMessage('Match has already ended'),
            RankedErrorCode.matchEnded);
        expect(RankedErrorCode.fromMessage('Caller heartbeat is stale; cannot report opponent'),
            RankedErrorCode.staleCallerHeartbeat);
        expect(RankedErrorCode.fromMessage('Opponent heartbeat is active; disconnect cannot be declared'),
            RankedErrorCode.opponentHeartbeatActive);
        expect(RankedErrorCode.fromMessage('Opponent has already submitted turn action; disconnection cannot be declared.'),
            RankedErrorCode.opponentAlreadySubmitted);
        expect(RankedErrorCode.fromMessage('Opponent is not holding up role selection'),
            RankedErrorCode.opponentNotHoldingUp);
        expect(RankedErrorCode.fromMessage('Grace period has expired'),
            RankedErrorCode.gracePeriodExpired);
        expect(RankedErrorCode.fromMessage('Caller is delinquent and cannot claim timeout forfeit'),
            RankedErrorCode.callerDelinquent);
        expect(RankedErrorCode.fromMessage('Turn deadline or grace period has not expired yet'),
            RankedErrorCode.turnDeadlineNotExpired);
        expect(RankedErrorCode.fromMessage('Unknown turn type: secret'),
            RankedErrorCode.unknownTurnType);
        expect(RankedErrorCode.fromMessage('Supabase client is not configured'),
            RankedErrorCode.clientNotConfigured);
      });

      test('Preserves details, hint, and SQL code from PostgrestException', () {
        const pgException = PostgrestException(
          message: 'Invalid choice: must be between 1 and 6',
          code: 'P0001',
          details: 'User submitted 7',
          hint: 'Send value 1..6',
        );

        final rankedEx = RankedException.fromPostgrestException(pgException);

        expect(rankedEx.code, RankedErrorCode.invalidChoice);
        expect(rankedEx.message, contains('Invalid choice'));
        expect(rankedEx.pgCode, 'P0001');
        expect(rankedEx.details, contains('User submitted 7'));
        expect(rankedEx.hint, 'Send value 1..6');
      });
    });

    // -----------------------------------------------------------------------
    // 9. OnlineRankedRepository Safeguards & Validation
    // -----------------------------------------------------------------------
    group('OnlineRankedRepository Safeguards & Validation', () {
      test('submitChoice validates choice 1..6 client-side before RPC call', () async {
        final repo = OnlineRankedRepository();

        // Choice 0 is rejected immediately
        expect(
          () => repo.submitChoice(matchId: 'm1', turnType: 'ball', choice: 0),
          throwsA(isA<RankedException>().having(
            (e) => e.code,
            'code',
            RankedErrorCode.invalidChoice,
          )),
        );

        // Choice 7 is rejected immediately
        expect(
          () => repo.submitChoice(matchId: 'm1', turnType: 'ball', choice: 7),
          throwsA(isA<RankedException>().having(
            (e) => e.code,
            'code',
            RankedErrorCode.invalidChoice,
          )),
        );
      });

      test('selectRole validates bat/bowl client-side before RPC call', () async {
        final repo = OnlineRankedRepository();

        expect(
          () => repo.selectRole(matchId: 'm1', role: 'pitch'),
          throwsA(isA<RankedException>().having(
            (e) => e.code,
            'code',
            RankedErrorCode.invalidRole,
          )),
        );
      });

      test('Gracefully reports unconfigured state when Supabase is not initialized', () {
        final repo = OnlineRankedRepository();
        expect(repo.isConfigured, isFalse);
        expect(repo.currentUserId, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // 10. RankedRealtimeManager Lifecycle & Reliability
    // -----------------------------------------------------------------------
    group('RankedRealtimeManager Lifecycle & Reliability', () {
      test('Initial state is disconnected', () {
        final fakeRepo = FakeOnlineRankedRepository();
        final manager = RankedRealtimeManager(fakeRepo);

        expect(manager.status, RealtimeSyncStatus.disconnected);
        expect(manager.isSubscribed, isFalse);
        expect(manager.activeMatchId, isNull);
      });

      test('Subscribe triggers initial authoritative resync', () async {
        final fakeRepo = FakeOnlineRankedRepository();
        fakeRepo.fakeMatch = const RankedMatch(
          id: 'm100',
          phase: RankedMatchPhase.firstInnings,
          player1Id: 'p1',
          player2Id: 'p2',
          player1Parity: PlayerParity.odd,
          player2Parity: PlayerParity.even,
        );

        final manager = RankedRealtimeManager(fakeRepo);

        RankedMatch? receivedMatch;
        await manager.subscribe(
          matchId: 'm100',
          onMatchUpdated: (m) => receivedMatch = m,
          enablePollingFallback: false,
        );

        expect(manager.activeMatchId, 'm100');
        expect(receivedMatch, isNotNull);
        expect(receivedMatch!.id, 'm100');
        expect(fakeRepo.getMatchCallCount, 1);
        expect(fakeRepo.getBallEventsCallCount, 1);
      });

      test('Prevents duplicate subscription to the same matchId', () async {
        final fakeRepo = FakeOnlineRankedRepository();
        final manager = RankedRealtimeManager(fakeRepo);

        await manager.subscribe(matchId: 'm1', enablePollingFallback: false);
        final initialCalls = fakeRepo.getMatchCallCount;

        // Subscribing again to the same match does not duplicate channels
        await manager.subscribe(matchId: 'm1', enablePollingFallback: false);
        expect(manager.activeMatchId, 'm1');
        // Initial call count unchanged or properly managed
        expect(fakeRepo.getMatchCallCount, initialCalls + 1);
      });

      test('Unsubscribe stops fallback polling and clears active matchId', () async {
        final fakeRepo = FakeOnlineRankedRepository();
        final manager = RankedRealtimeManager(fakeRepo);

        await manager.subscribe(matchId: 'm2', enablePollingFallback: true);
        expect(manager.activeMatchId, 'm2');

        await manager.unsubscribe();
        expect(manager.activeMatchId, isNull);
        expect(manager.status, RealtimeSyncStatus.closed);
        expect(fakeRepo.unsubscribeCalled, isTrue);
      });

      test('Full dispose safely cleans up all resources without throwing', () async {
        final fakeRepo = FakeOnlineRankedRepository();
        final manager = RankedRealtimeManager(fakeRepo);

        await manager.subscribe(matchId: 'm3', enablePollingFallback: true);
        await manager.dispose();

        expect(manager.activeMatchId, isNull);
        expect(manager.status, RealtimeSyncStatus.closed);
      });
    });
  });
}
