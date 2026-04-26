import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod/riverpod.dart';
import '../models/event.dart';
import '../models/performer.dart';
import '../models/vote.dart';

final eventServiceProvider = Provider<EventService>((ref) {
  return EventService();
});

class EventService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Event CRUD Operations
  Future<Event?> createEvent(Event event) async {
    try {
      // Ensure only one active event
      if (event.status == EventStatus.active) {
        await _deactivateAllActiveEvents();
      }

      final response = await _supabase
          .from('events')
          .insert(event.toJson())
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      debugPrint('Error creating event: $e');
      return null;
    }
  }

  Future<Event?> updateEvent(Event event) async {
    try {
      // If activating this event, deactivate others
      if (event.status == EventStatus.active) {
        await _deactivateAllActiveEvents();
      }

      final response = await _supabase
          .from('events')
          .update(event.toJson())
          .eq('id', event.id)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      debugPrint('Error updating event: $e');
      return null;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    try {
      await _supabase
          .from('events')
          .delete()
          .eq('id', eventId);

      return true;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  Future<Event?> getEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('id', eventId)
          .single();

      return Event.fromJson(response);
    } catch (e) {
      debugPrint('Error getting event: $e');
      return null;
    }
  }

  Future<List<Event>> getAllEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Event.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting all events: $e');
      return [];
    }
  }

  Future<Event?> getActiveEvent() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('status', 'active')
          .maybeSingle();

      return response != null ? Event.fromJson(response) : null;
    } catch (e) {
      debugPrint('Error getting active event: $e');
      return null;
    }
  }

  Future<List<Event>> getUpcomingEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('status', 'upcoming')
          .order('event_date', ascending: true);

      return (response as List)
          .map((json) => Event.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting upcoming events: $e');
      return [];
    }
  }

  Future<List<Event>> getCompletedEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('status', 'completed')
          .order('event_date', ascending: false);

      return (response as List)
          .map((json) => Event.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting completed events: $e');
      return [];
    }
  }

  // Event Lifecycle Management
  Future<Event?> activateEvent(String eventId) async {
    try {
      await _deactivateAllActiveEvents();

      final response = await _supabase
          .from('events')
          .update({'status': 'active'})
          .eq('id', eventId)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      debugPrint('Error activating event: $e');
      return null;
    }
  }

  Future<Event?> deactivateEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('events')
          .update({'status': 'upcoming'})
          .eq('id', eventId)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      debugPrint('Error deactivating event: $e');
      return null;
    }
  }

  Future<Event?> completeEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('events')
          .update({'status': 'completed'})
          .eq('id', eventId)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      debugPrint('Error completing event: $e');
      return null;
    }
  }

  Future<bool> _deactivateAllActiveEvents() async {
    try {
      await _supabase
          .from('events')
          .update({'status': 'upcoming'})
          .eq('status', 'active');

      return true;
    } catch (e) {
      debugPrint('Error deactivating active events: $e');
      return false;
    }
  }

  // Voting Control
  Future<bool> resetVotesForEvent(String eventId) async {
    try {
      await _supabase
          .from('votes')
          .delete()
          .eq('event_id', eventId);

      return true;
    } catch (e) {
      debugPrint('Error resetting votes: $e');
      return false;
    }
  }

  Future<List<Vote>> getVotesForEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select('*, performers(*, users(*))')
          .eq('event_id', eventId)
          .order('voted_at', ascending: false);

      return (response as List).map((json) => Vote.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting votes for event: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getEventAnalytics(String eventId) async {
    try {
      // Get vote counts by performer
      final votesResponse = await _supabase
          .from('votes')
          .select('performer_id, score')
          .eq('event_id', eventId);

      // Get registration counts
      final registrationsResponse = await _supabase
          .from('event_registrations')
          .select('status')
          .eq('event_id', eventId);

      // Get unique voters
      final votersResponse = await _supabase
          .from('votes')
          .select('user_id')
          .eq('event_id', eventId);

      final votes = votesResponse as List;
      final registrations = registrationsResponse as List;
      final voters = votersResponse as List;

      // Calculate analytics
      final totalVotes = votes.length;
      final uniqueVoters = voters.map((v) => v['user_id']).toSet().length;
      final totalRegistrations = registrations.length;
      final approvedRegistrations = registrations
          .where((r) => r['status'] == 'approved')
          .length;

      // Group votes by performer
      final performerVotes = <String, List<int>>{};
      for (final vote in votes) {
        final performerId = vote['performer_id'] as String;
        final score = vote['score'] as int;
        performerVotes.putIfAbsent(performerId, () => []).add(score);
      }

      // Calculate averages
      final performerAverages = <String, double>{};
      for (final entry in performerVotes.entries) {
        final scores = entry.value;
        final average = scores.reduce((a, b) => a + b) / scores.length;
        performerAverages[entry.key] = average;
      }

      return {
        'totalVotes': totalVotes,
        'uniqueVoters': uniqueVoters,
        'totalRegistrations': totalRegistrations,
        'approvedRegistrations': approvedRegistrations,
        'performerVotes': performerVotes,
        'performerAverages': performerAverages,
      };
    } catch (e) {
      debugPrint('Error getting event analytics: $e');
      return {};
    }
  }

  // System-wide Analytics
  Future<Map<String, dynamic>> getSystemAnalytics() async {
    try {
      // Get total users
      final usersResponse = await _supabase
          .from('users')
          .select('role');

      // Get total performers
      final performersResponse = await _supabase
          .from('performers')
          .select();

      // Get total votes
      final votesResponse = await _supabase
          .from('votes')
          .select();

      // Get total events
      final eventsResponse = await _supabase
          .from('events')
          .select('status');

      final users = usersResponse as List;
      final performers = performersResponse as List;
      final votes = votesResponse as List;
      final events = eventsResponse as List;

      // Calculate role breakdown
      final roleCounts = <String, int>{};
      for (final user in users) {
        final role = user['role'] as String;
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;
      }

      // Calculate event status breakdown
      final eventStatusCounts = <String, int>{};
      for (final event in events) {
        final status = event['status'] as String;
        eventStatusCounts[status] = (eventStatusCounts[status] ?? 0) + 1;
      }

      return {
        'totalUsers': users.length,
        'totalPerformers': performers.length,
        'totalVotes': votes.length,
        'totalEvents': events.length,
        'roleCounts': roleCounts,
        'eventStatusCounts': eventStatusCounts,
      };
    } catch (e) {
      debugPrint('Error getting system analytics: $e');
      return {};
    }
  }

  // Performer Management for Admin
  Future<List<Performer>> getAllPerformersWithApprovalStatus() async {
    try {
      final response = await _supabase
          .from('performers')
          .select('*, users(*)')
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final performerData = Map<String, dynamic>.from(json);
        performerData.addAll(json['users'] as Map<String, dynamic>);
        return Performer.fromJson(performerData);
      }).toList();
    } catch (e) {
      debugPrint('Error getting performers with approval status: $e');
      return [];
    }
  }

  Future<bool> approvePerformer(String performerId) async {
    try {
      // TODO: Implement approval status in database
      // For now, we'll return true as a placeholder
      debugPrint('Approving performer: $performerId');
      return true;
    } catch (e) {
      debugPrint('Error approving performer: $e');
      return false;
    }
  }

  Future<bool> rejectPerformer(String performerId) async {
    try {
      // TODO: Implement rejection status in database
      // For now, we'll return true as a placeholder
      debugPrint('Rejecting performer: $performerId');
      return true;
    } catch (e) {
      debugPrint('Error rejecting performer: $e');
      return false;
    }
  }

  Future<bool> deletePerformer(String performerId) async {
    try {
      await _supabase
          .from('performers')
          .delete()
          .eq('id', performerId);

      return true;
    } catch (e) {
      debugPrint('Error deleting performer: $e');
      return false;
    }
  }
}
