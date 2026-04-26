import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod/riverpod.dart';

final rankingServiceProvider = Provider<RankingService>((ref) => RankingService());

class RankingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Returns a list of {performerId, name, votes, averageScore, rank} maps
  Future<List<Map<String, dynamic>>> getEventLeaderboard(String eventId) async {
    try {
      final votes = await _supabase
          .from('votes')
          .select('performer_id, score')
          .eq('event_id', eventId);

      final performers = await _supabase
          .from('performers')
          .select('id, talent_type, users!inner(id, name, email)');

      final votesList = (votes as List).cast<Map<String, dynamic>>();
      final performersList = (performers as List).cast<Map<String, dynamic>>();

      // Aggregate votes per performer
      final voteMap = <String, List<int>>{};
      for (final v in votesList) {
        final pid = v['performer_id'] as String;
        final score = v['score'] as int;
        voteMap.putIfAbsent(pid, () => []).add(score);
      }

      final ranked = performersList.map((p) {
        final user = Map<String, dynamic>.from(p['users'] as Map);
        final pid = p['id'] as String;
        final scores = voteMap[pid] ?? [];
        final totalVotes = scores.length;
        final avgScore = scores.isEmpty
            ? 0.0
            : scores.reduce((a, b) => a + b) / scores.length;
        return {
          'performerId': pid,
          'name': user['name'] ?? user['email'] ?? 'Unknown',
          'talentType': p['talent_type'] ?? 'other',
          'votes': totalVotes,
          'averageScore': avgScore,
        };
      }).toList()
        ..sort((a, b) => (b['votes'] as int).compareTo(a['votes'] as int));

      // Add rank
      for (var i = 0; i < ranked.length; i++) {
        ranked[i]['rank'] = i + 1;
      }

      return ranked;
    } catch (e) {
      debugPrint('RankingService.getEventLeaderboard error: $e');
      return [];
    }
  }

  /// Returns vote count for a specific performer in an event
  Future<int> getPerformerVoteCount(String performerId, String eventId) async {
    try {
      final result = await _supabase
          .from('votes')
          .select('id')
          .eq('performer_id', performerId)
          .eq('event_id', eventId);
      return (result as List).length;
    } catch (e) {
      debugPrint('RankingService.getPerformerVoteCount error: $e');
      return 0;
    }
  }

  /// Returns average score for a performer in an event
  Future<double> getPerformerAverageScore(
      String performerId, String eventId) async {
    try {
      final result = await _supabase
          .from('votes')
          .select('score')
          .eq('performer_id', performerId)
          .eq('event_id', eventId);
      final scores = (result as List).map((r) => r['score'] as int).toList();
      if (scores.isEmpty) return 0.0;
      return scores.reduce((a, b) => a + b) / scores.length;
    } catch (e) {
      debugPrint('RankingService.getPerformerAverageScore error: $e');
      return 0.0;
    }
  }
}
