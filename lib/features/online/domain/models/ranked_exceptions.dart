import 'package:supabase_flutter/supabase_flutter.dart';

/// Error codes returned or mapped from PostgreSQL Ranked RPC exceptions.
enum RankedErrorCode {
  notAuthenticated,
  invalidChoice,
  notParticipant,
  matchNotFound,
  invalidRole,
  invalidPhase,
  notTossWinner,
  matchEnded,
  staleCallerHeartbeat,
  opponentHeartbeatActive,
  opponentAlreadySubmitted,
  opponentNotHoldingUp,
  gracePeriodExpired,
  callerDelinquent,
  turnDeadlineNotExpired,
  unknownTurnType,
  activeMatchExists,
  clientNotConfigured,
  networkError,
  unknown;

  static RankedErrorCode fromMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('not authenticated')) {
      return RankedErrorCode.notAuthenticated;
    } else if (lower.contains('invalid choice') || lower.contains('between 1 and 6')) {
      return RankedErrorCode.invalidChoice;
    } else if (lower.contains('not a participant')) {
      return RankedErrorCode.notParticipant;
    } else if (lower.contains('match not found')) {
      return RankedErrorCode.matchNotFound;
    } else if (lower.contains('invalid role')) {
      return RankedErrorCode.invalidRole;
    } else if (lower.contains('not in role_selection phase') ||
        lower.contains('not in innings_break phase')) {
      return RankedErrorCode.invalidPhase;
    } else if (lower.contains('only the toss winner')) {
      return RankedErrorCode.notTossWinner;
    } else if (lower.contains('already ended') || lower.contains('already concluded')) {
      return RankedErrorCode.matchEnded;
    } else if (lower.contains('caller heartbeat is stale')) {
      return RankedErrorCode.staleCallerHeartbeat;
    } else if (lower.contains('opponent heartbeat is active')) {
      return RankedErrorCode.opponentHeartbeatActive;
    } else if (lower.contains('already submitted turn action')) {
      return RankedErrorCode.opponentAlreadySubmitted;
    } else if (lower.contains('not holding up role selection')) {
      return RankedErrorCode.opponentNotHoldingUp;
    } else if (lower.contains('grace period has expired')) {
      return RankedErrorCode.gracePeriodExpired;
    } else if (lower.contains('caller is delinquent')) {
      return RankedErrorCode.callerDelinquent;
    } else if (lower.contains('has not expired yet')) {
      return RankedErrorCode.turnDeadlineNotExpired;
    } else if (lower.contains('unknown turn type')) {
      return RankedErrorCode.unknownTurnType;
    } else if (lower.contains('active_match_exists')) {
      return RankedErrorCode.activeMatchExists;
    } else if (lower.contains('not configured') || lower.contains('not initialized')) {
      return RankedErrorCode.clientNotConfigured;
    } else if (lower.contains('socket') || lower.contains('network') || lower.contains('connection')) {
      return RankedErrorCode.networkError;
    }
    return RankedErrorCode.unknown;
  }
}

/// Structured exception representing an error during Online Ranked operations.
class RankedException implements Exception {
  final RankedErrorCode code;
  final String message;
  final String? details;
  final String? hint;
  final String? pgCode;

  const RankedException({
    required this.code,
    required this.message,
    this.details,
    this.hint,
    this.pgCode,
  });

  factory RankedException.fromPostgrestException(PostgrestException e) {
    return RankedException(
      code: RankedErrorCode.fromMessage(e.message),
      message: e.message,
      details: e.details?.toString(),
      hint: e.hint,
      pgCode: e.code,
    );
  }

  factory RankedException.fromException(Object e) {
    if (e is RankedException) return e;
    if (e is PostgrestException) return RankedException.fromPostgrestException(e);
    if (e is AuthException) {
      return RankedException(
        code: RankedErrorCode.notAuthenticated,
        message: e.message,
        pgCode: e.statusCode,
      );
    }
    final msg = e.toString();
    return RankedException(
      code: RankedErrorCode.fromMessage(msg),
      message: msg,
    );
  }

  @override
  String toString() {
    return 'RankedException(code: $code, message: $message, details: $details, pgCode: $pgCode)';
  }
}
