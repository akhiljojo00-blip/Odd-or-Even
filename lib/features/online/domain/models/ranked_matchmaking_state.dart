/// State status of the ranked matchmaking queue lifecycle.
enum RankedMatchmakingStatus {
  idle,
  queued,
  matched,
  activeMatchExists,
  notQueued,
  cancelled,
  error;

  static RankedMatchmakingStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'queued':
        return RankedMatchmakingStatus.queued;
      case 'matched':
        return RankedMatchmakingStatus.matched;
      case 'active_match_exists':
        return RankedMatchmakingStatus.activeMatchExists;
      case 'not_queued':
        return RankedMatchmakingStatus.notQueued;
      case 'cancelled':
        return RankedMatchmakingStatus.cancelled;
      default:
        return RankedMatchmakingStatus.idle;
    }
  }
}

/// Response returned from `rpc_join_ranked_matchmaking` and `rpc_poll_ranked_matchmaking`.
class RankedMatchmakingResult {
  final RankedMatchmakingStatus status;
  final String? matchId;
  final String? message;

  const RankedMatchmakingResult({
    required this.status,
    this.matchId,
    this.message,
  });

  bool get isQueued => status == RankedMatchmakingStatus.queued;
  bool get isMatched => status == RankedMatchmakingStatus.matched;
  bool get hasActiveMatch => status == RankedMatchmakingStatus.activeMatchExists;
  bool get isCancelled => status == RankedMatchmakingStatus.cancelled;
  bool get isError => status == RankedMatchmakingStatus.error;

  factory RankedMatchmakingResult.fromJson(Map<String, dynamic> json) {
    return RankedMatchmakingResult(
      status: RankedMatchmakingStatus.fromString(json['status'] as String?),
      matchId: json['match_id'] as String?,
      message: json['message'] as String?,
    );
  }

  factory RankedMatchmakingResult.error(String message) {
    return RankedMatchmakingResult(
      status: RankedMatchmakingStatus.error,
      message: message,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'match_id': matchId,
      'message': message,
    };
  }
}
