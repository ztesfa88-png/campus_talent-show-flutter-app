import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod/riverpod.dart';
import '../models/vote.dart';
import '../models/event.dart';

final hardenedVotingServiceProvider = Provider<HardenedVotingService>((ref) {
  return HardenedVotingService();
});

class HardenedVotingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Rate limiting configuration
  static const int _maxVotesPerMinute = 10;
  static const int _maxVotesPerHour = 50;
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static const Duration _hourlyRateLimitWindow = Duration(hours: 1);

  // Vote submission with hard constraints
  Future<VoteSubmissionResult> submitVote({
    required String eventId,
    required String userId,
    required String performerId,
    required int score,
  }) async {
    try {
      // Validate inputs
      if (score < 1 || score > 5) {
        return VoteSubmissionResult.error('Invalid score. Must be between 1 and 5.');
      }

      // Check if event is active
      final event = await _getEvent(eventId);
      if (event == null) {
        return VoteSubmissionResult.error('Event not found.');
      }

      if (event.status != EventStatus.active) {
        return VoteSubmissionResult.error('Voting is only allowed during active events.');
      }

      // Check voting deadline
      if (event.votingDeadline != null && DateTime.now().isAfter(event.votingDeadline!)) {
        return VoteSubmissionResult.error('Voting has closed for this event.');
      }

      // Check event expiry
      if (event.isExpired) {
        return VoteSubmissionResult.error('This event has expired.');
      }

      // Prevent self-voting
      if (userId == performerId) {
        return VoteSubmissionResult.error('You cannot vote for yourself.');
      }

      // Check rate limits
      final rateLimitResult = await _checkRateLimits(userId);
      if (!rateLimitResult.allowed) {
        return VoteSubmissionResult.error(rateLimitResult.reason ?? 'Rate limit exceeded.');
      }

      // Check if user has already voted for this performer in this event
      final existingVote = await _getExistingVote(eventId, userId, performerId);
      if (existingVote != null) {
        return VoteSubmissionResult.error('You have already voted for this performer in this event.');
      }

      // Use database transaction to prevent race conditions
      final vote = await _submitVoteTransaction(
        eventId: eventId,
        userId: userId,
        performerId: performerId,
        score: score,
      );

      if (vote != null) {
        return VoteSubmissionResult.success(vote);
      } else {
        return VoteSubmissionResult.error('Failed to submit vote. Please try again.');
      }
    } catch (e) {
      debugPrint('Error submitting vote: $e');
      return VoteSubmissionResult.error('An error occurred while submitting your vote.');
    }
  }

  // Database transaction to prevent race conditions
  Future<Vote?> _submitVoteTransaction({
    required String eventId,
    required String userId,
    required String performerId,
    required int score,
  }) async {
    try {
      // Use RPC function for atomic vote submission
      final response = await _supabase.rpc('submit_vote', params: {
        'p_event_id': eventId,
        'p_user_id': userId,
        'p_performer_id': performerId,
        'p_score': score,
      });

      if (response != null) {
        return Vote.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Transaction error: $e');
      return null;
    }
  }

  // Rate limiting check
  Future<RateLimitResult> _checkRateLimits(String userId) async {
    try {
      final now = DateTime.now();
      final minuteAgo = now.subtract(_rateLimitWindow);
      final hourAgo = now.subtract(_hourlyRateLimitWindow);

      // Check votes in the last minute
      final minuteVotesResponse = await _supabase
          .from('votes')
          .select('id')
          .eq('user_id', userId)
          .gte('voted_at', minuteAgo.toIso8601String());

      final minuteVotes = (minuteVotesResponse as List).length;
      if (minuteVotes >= _maxVotesPerMinute) {
        return RateLimitResult.denied('Too many votes. Please wait a moment before voting again.');
      }

      // Check votes in the last hour
      final hourVotesResponse = await _supabase
          .from('votes')
          .select('id')
          .eq('user_id', userId)
          .gte('voted_at', hourAgo.toIso8601String());

      final hourVotes = (hourVotesResponse as List).length;
      if (hourVotes >= _maxVotesPerHour) {
        return RateLimitResult.denied('Hourly vote limit reached. Please try again later.');
      }

      return RateLimitResult.allowed();
    } catch (e) {
      debugPrint('Rate limit check error: $e');
      return RateLimitResult.denied('Unable to verify rate limits. Please try again.');
    }
  }

  // Check for existing vote
  Future<Vote?> _getExistingVote(String eventId, String userId, String performerId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .eq('performer_id', performerId)
          .maybeSingle();

      return response != null ? Vote.fromJson(response) : null;
    } catch (e) {
      debugPrint('Error checking existing vote: $e');
      return null;
    }
  }

  // Get event details
  Future<Event?> _getEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('id', eventId)
          .maybeSingle();

      return response != null ? Event.fromJson(response) : null;
    } catch (e) {
      debugPrint('Error getting event: $e');
      return null;
    }
  }

  // Get user's votes for an event
  Future<List<Vote>> getUserVotesForEvent(String userId, String eventId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select('*, performers(*)')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .order('voted_at', ascending: false);

      return (response as List).map((json) => Vote.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting user votes: $e');
      return [];
    }
  }

  // Check if user can vote for performer
  Future<VotingEligibility> checkVotingEligibility({
    required String userId,
    required String eventId,
    required String performerId,
  }) async {
    try {
      // Check event status
      final event = await _getEvent(eventId);
      if (event == null) {
        return VotingEligibility.ineligible('Event not found.');
      }

      if (event.status != EventStatus.active) {
        return VotingEligibility.ineligible('Voting is only allowed during active events.');
      }

      // Check voting deadline
      if (event.votingDeadline != null && DateTime.now().isAfter(event.votingDeadline!)) {
        return VotingEligibility.ineligible('Voting has closed for this event.');
      }

      // Check event expiry
      if (event.isExpired) {
        return VotingEligibility.ineligible('This event has expired.');
      }

      // Prevent self-voting
      if (userId == performerId) {
        return VotingEligibility.ineligible('You cannot vote for yourself.');
      }

      // Check existing vote
      final existingVote = await _getExistingVote(eventId, userId, performerId);
      if (existingVote != null) {
        return VotingEligibility.ineligible('You have already voted for this performer.');
      }

      // Check rate limits
      final rateLimitResult = await _checkRateLimits(userId);
      if (!rateLimitResult.allowed) {
        return VotingEligibility.ineligible(rateLimitResult.reason ?? 'Rate limit exceeded.');
      }

      return VotingEligibility.eligible();
    } catch (e) {
      debugPrint('Error checking voting eligibility: $e');
      return VotingEligibility.ineligible('Unable to verify voting eligibility.');
    }
  }

  // Get voting statistics for an event
  Future<Map<String, dynamic>> getEventVotingStats(String eventId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select('performer_id, score, voted_at')
          .eq('event_id', eventId);

      final votes = response as List;
      
      // Calculate statistics
      final performerVotes = <String, List<int>>{};
      final performerAverages = <String, double>{};
      final voteTimes = votes.map((v) => DateTime.parse(v['voted_at'])).toList();

      for (final vote in votes) {
        final performerId = vote['performer_id'] as String;
        final score = vote['score'] as int;
        performerVotes.putIfAbsent(performerId, () => []).add(score);
      }

      // Calculate averages
      for (final entry in performerVotes.entries) {
        final scores = entry.value;
        final average = scores.reduce((a, b) => a + b) / scores.length;
        performerAverages[entry.key] = average;
      }

      // Sort by average rating
      final sortedPerformers = performerAverages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'totalVotes': votes.length,
        'uniqueVoters': voteTimes.toSet().length,
        'performerVotes': performerVotes,
        'performerAverages': performerAverages,
        'leaderboard': sortedPerformers,
        'lastVoteTime': voteTimes.isNotEmpty ? voteTimes.reduce((a, b) => a.isAfter(b) ? a : b) : null,
      };
    } catch (e) {
      debugPrint('Error getting voting stats: $e');
      return {};
    }
  }

  // Reset all votes for an event (admin function)
  Future<bool> resetEventVotes(String eventId) async {
    try {
      await _supabase
          .from('votes')
          .delete()
          .eq('event_id', eventId);

      return true;
    } catch (e) {
      debugPrint('Error resetting event votes: $e');
      return false;
    }
  }

  // Get user's voting rate limit status
  Future<Map<String, dynamic>> getUserRateLimitStatus(String userId) async {
    try {
      final now = DateTime.now();
      final minuteAgo = now.subtract(_rateLimitWindow);
      final hourAgo = now.subtract(_hourlyRateLimitWindow);

      final minuteVotesResponse = await _supabase
          .from('votes')
          .select('id')
          .eq('user_id', userId)
          .gte('voted_at', minuteAgo.toIso8601String());

      final hourVotesResponse = await _supabase
          .from('votes')
          .select('id')
          .eq('user_id', userId)
          .gte('voted_at', hourAgo.toIso8601String());

      final minuteVotes = (minuteVotesResponse as List).length;
      final hourVotes = (hourVotesResponse as List).length;

      return {
        'votesInLastMinute': minuteVotes,
        'votesInLastHour': hourVotes,
        'maxVotesPerMinute': _maxVotesPerMinute,
        'maxVotesPerHour': _maxVotesPerHour,
        'canVote': minuteVotes < _maxVotesPerMinute && hourVotes < _maxVotesPerHour,
        'minuteVotesRemaining': (_maxVotesPerMinute - minuteVotes).clamp(0, _maxVotesPerMinute),
        'hourVotesRemaining': (_maxVotesPerHour - hourVotes).clamp(0, _maxVotesPerHour),
      };
    } catch (e) {
      debugPrint('Error getting rate limit status: $e');
      return {};
    }
  }
}

// Vote submission result
class VoteSubmissionResult {
  final bool success;
  final Vote? vote;
  final String? error;

  VoteSubmissionResult._({required this.success, this.vote, this.error});

  factory VoteSubmissionResult.success(Vote vote) {
    return VoteSubmissionResult._(success: true, vote: vote);
  }

  factory VoteSubmissionResult.error(String error) {
    return VoteSubmissionResult._(success: false, error: error);
  }
}

// Rate limit result
class RateLimitResult {
  final bool allowed;
  final String? reason;

  RateLimitResult._({required this.allowed, this.reason});

  factory RateLimitResult.allowed() {
    return RateLimitResult._(allowed: true);
  }

  factory RateLimitResult.denied(String reason) {
    return RateLimitResult._(allowed: false, reason: reason);
  }
}

// Voting eligibility
class VotingEligibility {
  final bool eligible;
  final String? reason;

  VotingEligibility._({required this.eligible, this.reason});

  factory VotingEligibility.eligible() {
    return VotingEligibility._(eligible: true);
  }

  factory VotingEligibility.ineligible(String reason) {
    return VotingEligibility._(eligible: false, reason: reason);
  }
}
