import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod/riverpod.dart';
import '../models/user.dart' as app_user;
import '../models/performer.dart';
import '../models/event.dart';
import '../models/vote.dart';
import '../models/notification.dart';
import '../models/feedback.dart';
import '../models/event_registration.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // User operations
  Future<app_user.User?> getUser(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      
      return app_user.User.fromJson(response);
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  Future<List<app_user.User>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => app_user.User.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }

  Future<app_user.User?> updateUser(app_user.User user) async {
    try {
      final response = await _supabase
          .from('users')
          .update(user.toJson())
          .eq('id', user.id)
          .select()
          .single();
      
      return app_user.User.fromJson(response);
    } catch (e) {
      debugPrint('Error updating user: $e');
      return null;
    }
  }

  // Performer operations
  Future<Performer?> getPerformer(String performerId) async {
    try {
      final response = await _supabase
          .from('performers')
          .select('*, users(*)')
          .eq('id', performerId)
          .single();
      
      // Merge performer and user data
      final performerData = Map<String, dynamic>.from(response);
      performerData.addAll(response['users'] as Map<String, dynamic>);
      
      return Performer.fromJson(performerData);
    } catch (e) {
      debugPrint('Error getting performer: $e');
      return null;
    }
  }

  Future<List<Performer>> getAllPerformers() async {
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
      debugPrint('Error getting all performers: $e');
      return [];
    }
  }

  Future<Performer?> createPerformer(Performer performer) async {
    try {
      final response = await _supabase
          .from('performers')
          .insert(performer.toJson())
          .select()
          .single();
      
      return Performer.fromJson(response);
    } catch (e) {
      debugPrint('Error creating performer: $e');
      return null;
    }
  }

  Future<Performer?> updatePerformer(Performer performer) async {
    try {
      final response = await _supabase
          .from('performers')
          .update(performer.toJson())
          .eq('id', performer.id)
          .select()
          .single();
      
      return Performer.fromJson(response);
    } catch (e) {
      debugPrint('Error updating performer: $e');
      return null;
    }
  }

  // Event operations
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
          .order('event_date', ascending: true);
      
      return (response as List)
          .map((json) => Event.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting all events: $e');
      return [];
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

  Future<Event?> createEvent(Event event) async {
    try {
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

  // Event registration operations
  Future<EventRegistration?> getRegistration(String registrationId) async {
    try {
      final response = await _supabase
          .from('event_registrations')
          .select()
          .eq('id', registrationId)
          .single();
      
      return EventRegistration.fromJson(response);
    } catch (e) {
      debugPrint('Error getting registration: $e');
      return null;
    }
  }

  Future<List<EventRegistration>> getRegistrationsByEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('event_registrations')
          .select('*, performers(*, users(*))')
          .eq('event_id', eventId)
          .order('submission_date', ascending: true);
      
      return (response as List).map((json) => EventRegistration.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting registrations by event: $e');
      return [];
    }
  }

  Future<List<EventRegistration>> getRegistrationsByPerformer(String performerId) async {
    try {
      final response = await _supabase
          .from('event_registrations')
          .select('*, events(*)')
          .eq('performer_id', performerId)
          .order('submission_date', ascending: false);
      
      return (response as List).map((json) => EventRegistration.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting registrations by performer: $e');
      return [];
    }
  }

  Future<EventRegistration?> createRegistration(EventRegistration registration) async {
    try {
      final response = await _supabase
          .from('event_registrations')
          .insert(registration.toJson())
          .select()
          .single();
      
      return EventRegistration.fromJson(response);
    } catch (e) {
      debugPrint('Error creating registration: $e');
      return null;
    }
  }

  Future<EventRegistration?> updateRegistration(EventRegistration registration) async {
    try {
      final response = await _supabase
          .from('event_registrations')
          .update(registration.toJson())
          .eq('id', registration.id)
          .select()
          .single();
      
      return EventRegistration.fromJson(response);
    } catch (e) {
      debugPrint('Error updating registration: $e');
      return null;
    }
  }

  // Vote operations
  Future<Vote?> getVote(String userId, String eventId, String performerId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select()
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .eq('performer_id', performerId)
          .maybeSingle();
      
      return response != null ? Vote.fromJson(response) : null;
    } catch (e) {
      debugPrint('Error getting vote: $e');
      return null;
    }
  }

  Future<List<Vote>> getVotesByEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select('*, performers(*, users(*))')
          .eq('event_id', eventId)
          .order('voted_at', ascending: false);
      
      return (response as List).map((json) => Vote.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting votes by event: $e');
      return [];
    }
  }

  Future<List<Vote>> getVotesByPerformer(String performerId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select('*, events(*)')
          .eq('performer_id', performerId)
          .order('voted_at', ascending: false);
      
      return (response as List).map((json) => Vote.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting votes by performer: $e');
      return [];
    }
  }

  Future<Vote?> createVote(Vote vote) async {
    try {
      final response = await _supabase
          .from('votes')
          .insert(vote.toJson())
          .select()
          .single();
      
      return Vote.fromJson(response);
    } catch (e) {
      debugPrint('Error creating vote: $e');
      return null;
    }
  }

  // Notification operations
  Future<List<AppNotification>> getNotificationsByUser(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting notifications by user: $e');
      return [];
    }
  }

  Future<AppNotification?> createNotification(AppNotification notification) async {
    try {
      final response = await _supabase
          .from('notifications')
          .insert(notification.toJson())
          .select()
          .single();
      
      return AppNotification.fromJson(response);
    } catch (e) {
      debugPrint('Error creating notification: $e');
      return null;
    }
  }

  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  // Feedback operations
  Future<List<Feedback>> getFeedbackByEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('feedback')
          .select('*, users(*), performers(*, users(*))')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);
      
      return (response as List).map((json) => Feedback.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting feedback by event: $e');
      return [];
    }
  }

  Future<List<Feedback>> getFeedbackByPerformer(String performerId) async {
    try {
      final response = await _supabase
          .from('feedback')
          .select('*, users(*), events(*)')
          .eq('performer_id', performerId)
          .order('created_at', ascending: false);
      
      return (response as List).map((json) => Feedback.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting feedback by performer: $e');
      return [];
    }
  }

  Future<Feedback?> createFeedback(Feedback feedback) async {
    try {
      final response = await _supabase
          .from('feedback')
          .insert(feedback.toJson())
          .select()
          .single();
      
      return Feedback.fromJson(response);
    } catch (e) {
      debugPrint('Error creating feedback: $e');
      return null;
    }
  }
}
