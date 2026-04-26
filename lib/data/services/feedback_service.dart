import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod/riverpod.dart';
import '../models/feedback.dart';

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService();
});

class FeedbackService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Feedback CRUD Operations
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

  Future<List<Feedback>> getFeedbackByUser(String userId) async {
    try {
      final response = await _supabase
          .from('feedback')
          .select('*, events(*), performers(*, users(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Feedback.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting feedback by user: $e');
      return [];
    }
  }

  Future<List<Feedback>> getAllFeedback() async {
    try {
      final response = await _supabase
          .from('feedback')
          .select('*, users(*), events(*), performers(*, users(*))')
          .order('created_at', ascending: false);

      return (response as List).map((json) => Feedback.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting all feedback: $e');
      return [];
    }
  }

  Future<List<Feedback>> getPublicFeedback() async {
    try {
      final response = await _supabase
          .from('feedback')
          .select('*, users(*), events(*), performers(*, users(*))')
          .eq('is_public', true)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Feedback.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting public feedback: $e');
      return [];
    }
  }

  Future<bool> updateFeedback(Feedback feedback) async {
    try {
      await _supabase
          .from('feedback')
          .update(feedback.toJson())
          .eq('id', feedback.id);

      return true;
    } catch (e) {
      debugPrint('Error updating feedback: $e');
      return false;
    }
  }

  Future<bool> deleteFeedback(String feedbackId) async {
    try {
      await _supabase
          .from('feedback')
          .delete()
          .eq('id', feedbackId);

      return true;
    } catch (e) {
      debugPrint('Error deleting feedback: $e');
      return false;
    }
  }

  // Feedback Statistics
  Future<Map<String, dynamic>> getFeedbackStatistics() async {
    try {
      // Get total feedback
      final totalResponse = await _supabase
          .from('feedback')
          .select('rating, is_public');

      final feedback = totalResponse as List;
      
      // Calculate statistics
      int totalFeedback = feedback.length;
      int publicFeedback = feedback.where((f) => f['is_public'] == true).length;
      int privateFeedback = totalFeedback - publicFeedback;
      
      // Rating breakdown
      final ratingCounts = <int, int>{};
      double totalRating = 0;
      int ratedFeedback = 0;

      for (final item in feedback) {
        final rating = item['rating'] as int?;
        if (rating != null) {
          ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
          totalRating += rating;
          ratedFeedback++;
        }
      }

      final averageRating = ratedFeedback > 0 ? totalRating / ratedFeedback : 0.0;

      return {
        'totalFeedback': totalFeedback,
        'publicFeedback': publicFeedback,
        'privateFeedback': privateFeedback,
        'ratedFeedback': ratedFeedback,
        'unratedFeedback': totalFeedback - ratedFeedback,
        'averageRating': averageRating,
        'ratingBreakdown': ratingCounts,
      };
    } catch (e) {
      debugPrint('Error getting feedback statistics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getEventFeedbackStatistics(String eventId) async {
    try {
      // Get feedback for specific event
      final response = await _supabase
          .from('feedback')
          .select('rating, is_public, performer_id')
          .eq('event_id', eventId);

      final feedback = response as List;
      
      // Calculate statistics
      int totalFeedback = feedback.length;
      int publicFeedback = feedback.where((f) => f['is_public'] == true).length;
      
      // Rating breakdown
      final ratingCounts = <int, int>{};
      double totalRating = 0;
      int ratedFeedback = 0;

      // Performer feedback breakdown
      final performerCounts = <String, int>{};
      final performerRatings = <String, List<int>>{};

      for (final item in feedback) {
        final rating = item['rating'] as int?;
        final performerId = item['performer_id'] as String?;
        
        if (rating != null) {
          ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
          totalRating += rating;
          ratedFeedback++;
        }
        
        if (performerId != null) {
          performerCounts[performerId] = (performerCounts[performerId] ?? 0) + 1;
          if (rating != null) {
            performerRatings.putIfAbsent(performerId, () => []).add(rating);
          }
        }
      }

      final averageRating = ratedFeedback > 0 ? totalRating / ratedFeedback : 0.0;

      // Calculate performer averages
      final performerAverages = <String, double>{};
      for (final entry in performerRatings.entries) {
        final ratings = entry.value;
        final average = ratings.reduce((a, b) => a + b) / ratings.length;
        performerAverages[entry.key] = average;
      }

      return {
        'totalFeedback': totalFeedback,
        'publicFeedback': publicFeedback,
        'privateFeedback': totalFeedback - publicFeedback,
        'ratedFeedback': ratedFeedback,
        'unratedFeedback': totalFeedback - ratedFeedback,
        'averageRating': averageRating,
        'ratingBreakdown': ratingCounts,
        'performerCounts': performerCounts,
        'performerAverages': performerAverages,
      };
    } catch (e) {
      debugPrint('Error getting event feedback statistics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getPerformerFeedbackStatistics(String performerId) async {
    try {
      // Get feedback for specific performer
      final response = await _supabase
          .from('feedback')
          .select('rating, is_public, event_id')
          .eq('performer_id', performerId);

      final feedback = response as List;
      
      // Calculate statistics
      int totalFeedback = feedback.length;
      int publicFeedback = feedback.where((f) => f['is_public'] == true).length;
      
      // Rating breakdown
      final ratingCounts = <int, int>{};
      double totalRating = 0;
      int ratedFeedback = 0;

      // Event feedback breakdown
      final eventCounts = <String, int>{};
      final eventRatings = <String, List<int>>{};

      for (final item in feedback) {
        final rating = item['rating'] as int?;
        final eventId = item['event_id'] as String?;
        
        if (rating != null) {
          ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
          totalRating += rating;
          ratedFeedback++;
        }
        
        if (eventId != null) {
          eventCounts[eventId] = (eventCounts[eventId] ?? 0) + 1;
          if (rating != null) {
            eventRatings.putIfAbsent(eventId, () => []).add(rating);
          }
        }
      }

      final averageRating = ratedFeedback > 0 ? totalRating / ratedFeedback : 0.0;

      // Calculate event averages
      final eventAverages = <String, double>{};
      for (final entry in eventRatings.entries) {
        final ratings = entry.value;
        final average = ratings.reduce((a, b) => a + b) / ratings.length;
        eventAverages[entry.key] = average;
      }

      return {
        'totalFeedback': totalFeedback,
        'publicFeedback': publicFeedback,
        'privateFeedback': totalFeedback - publicFeedback,
        'ratedFeedback': ratedFeedback,
        'unratedFeedback': totalFeedback - ratedFeedback,
        'averageRating': averageRating,
        'ratingBreakdown': ratingCounts,
        'eventCounts': eventCounts,
        'eventAverages': eventAverages,
      };
    } catch (e) {
      debugPrint('Error getting performer feedback statistics: $e');
      return {};
    }
  }

  // Feedback filtering and sorting
  Future<List<Feedback>> getFilteredFeedback({
    String? eventId,
    String? performerId,
    String? userId,
    int? minRating,
    int? maxRating,
    bool? isPublic,
    DateTime? startDate,
    DateTime? endDate,
    String? sortBy,
    bool? ascending,
  }) async {
    try {
      var query = _supabase
          .from('feedback')
          .select('*, users(*), events(*), performers(*, users(*))');

      // Apply filters
      if (eventId != null) {
        query = query.eq('event_id', eventId);
      }
      if (performerId != null) {
        query = query.eq('performer_id', performerId);
      }
      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      if (isPublic != null) {
        query = query.eq('is_public', isPublic);
      }

      // Execute query
      var response = await query;

      // Apply additional filters
      final feedback = (response as List).map((json) => Feedback.fromJson(json)).toList();

      // Filter by rating
      if (minRating != null) {
        feedback.retainWhere((f) => f.rating != null && f.rating! >= minRating);
      }
      if (maxRating != null) {
        feedback.retainWhere((f) => f.rating != null && f.rating! <= maxRating);
      }

      // Filter by date range
      if (startDate != null) {
        feedback.retainWhere((f) => f.createdAt.isAfter(startDate));
      }
      if (endDate != null) {
        feedback.retainWhere((f) => f.createdAt.isBefore(endDate));
      }

      // Sort results
      switch (sortBy) {
        case 'date':
          feedback.sort((a, b) => (ascending ?? false)
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt));
          break;
        case 'rating':
          feedback.sort((a, b) {
            final aRating = a.rating ?? 0;
            final bRating = b.rating ?? 0;
            return (ascending ?? false)
                ? aRating.compareTo(bRating)
                : bRating.compareTo(aRating);
          });
          break;
        case 'event':
          feedback.sort((a, b) => a.eventId.compareTo(b.eventId));
          break;
        case 'performer':
          feedback.sort((a, b) => (a.performerId ?? '').compareTo(b.performerId ?? ''));
          break;
        default:
          feedback.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      return feedback;
    } catch (e) {
      debugPrint('Error getting filtered feedback: $e');
      return [];
    }
  }

  // Feedback analytics
  Future<List<Map<String, dynamic>>> getTopPerformersByFeedback({int limit = 10}) async {
    try {
      final feedback = await getAllFeedback();
      
      // Group feedback by performer
      final performerFeedback = <String, List<Feedback>>{};
      for (final f in feedback) {
        if (f.performerId != null) {
          performerFeedback.putIfAbsent(f.performerId!, () => []).add(f);
        }
      }

      // Calculate averages and sort
      final performerStats = performerFeedback.entries.map((entry) {
        final performerId = entry.key;
        final performerFeedbacks = entry.value;
        
        final ratings = performerFeedbacks
            .where((f) => f.rating != null)
            .map((f) => f.rating!)
            .toList();
        
        final averageRating = ratings.isNotEmpty 
            ? ratings.reduce((a, b) => a + b) / ratings.length 
            : 0.0;
        
        return {
          'performerId': performerId,
          'averageRating': averageRating,
          'totalFeedback': performerFeedbacks.length,
          'ratedFeedback': ratings.length,
        };
      }).toList();

      // Sort by average rating (descending)
      performerStats.sort((a, b) => (b['averageRating'] as double).compareTo(a['averageRating'] as double));

      return performerStats.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting top performers by feedback: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFeedbackTrends({int days = 30}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      final feedback = await getFilteredFeedback(
        startDate: startDate,
        sortBy: 'date',
        ascending: true,
      );

      // Group by date
      final dailyFeedback = <DateTime, List<Feedback>>{};
      for (final f in feedback) {
        final date = DateTime(f.createdAt.year, f.createdAt.month, f.createdAt.day);
        dailyFeedback.putIfAbsent(date, () => []).add(f);
      }

      // Calculate daily statistics
      final trends = dailyFeedback.entries.map((entry) {
        final date = entry.key;
        final dayFeedback = entry.value;
        
        final ratings = dayFeedback
            .where((f) => f.rating != null)
            .map((f) => f.rating!)
            .toList();
        
        final averageRating = ratings.isNotEmpty 
            ? ratings.reduce((a, b) => a + b) / ratings.length 
            : 0.0;
        
        return {
          'date': date,
          'totalFeedback': dayFeedback.length,
          'ratedFeedback': ratings.length,
          'averageRating': averageRating,
        };
      }).toList();

      return trends;
    } catch (e) {
      debugPrint('Error getting feedback trends: $e');
      return [];
    }
  }
}
