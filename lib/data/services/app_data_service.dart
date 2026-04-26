import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import '../models/feedback.dart';
import '../models/notification.dart';
import '../models/performer.dart';
import '../models/vote.dart';

class AppDataService {
  AppDataService()
      : _supabase = Supabase.instance.client,
        _connectivity = Connectivity();

  final SupabaseClient _supabase;
  final Connectivity _connectivity;

  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'campus_talent_cache.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE cache_items('
          'cache_key TEXT PRIMARY KEY,'
          'payload TEXT NOT NULL,'
          'updated_at INTEGER NOT NULL'
          ')',
        );
      },
    );
    return _db!;
  }

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<void> _cache(String key, Object value) async {
    final db = await _database();
    await db.insert(
      'cache_items',
      {
        'cache_key': key,
        'payload': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> _readCache(String key) async {
    final db = await _database();
    final rows = await db.query(
      'cache_items',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload'] as String);
  }

  Future<List<Event>> getEvents() async {
    const cacheKey = 'events_all';
    try {
      if (await isOnline()) {
        final response = await _supabase
            .from('events')
            .select()
            .order('event_date', ascending: true);
        final events = (response as List)
            .map((row) => Event.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        await _cache(cacheKey, events.map((e) => e.toJson()).toList());
        return events;
      }
    } catch (_) {}

    // Offline fallback
    final cached = await _readCache(cacheKey);
    if (cached is List) {
      return cached
          .map((row) => Event.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    }
    return [];
  }

  Future<List<Performer>> getPerformers({
    String? eventId,
    String? search,
    TalentType? talentType,
  }) async {
    final cacheKey = 'performers_${eventId ?? 'all'}_${search ?? ''}_${talentType?.value ?? ''}';
    try {
      // Always try Supabase directly — isOnline() is unreliable on emulators/web
      var perfQuery = _supabase
          .from('performers')
          .select('id, bio, talent_type, experience_level, social_links, avatar_url, approval_status, created_at, updated_at')
          .eq('approval_status', 'approved');

      if (talentType != null) {
        perfQuery = perfQuery.eq('talent_type', talentType.value);
      }

      final perfRows = (await perfQuery as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      if (perfRows.isEmpty) return [];

      final ids = perfRows.map((r) => r['id'] as String).toList();
      final userRows = (await _supabase
          .from('users')
          .select('id, email, name, role')
          .inFilter('id', ids) as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      final userMap = {for (final u in userRows) u['id'] as String: u};

      var performers = perfRows.map((row) {
        final user = userMap[row['id'] as String] ?? <String, dynamic>{
          'id': row['id'], 'email': '', 'name': null, 'role': 'performer',
        };
        return Performer.fromJson(<String, dynamic>{...user, ...row});
      }).toList();

      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        performers = performers
            .where((p) => (p.name ?? p.email).toLowerCase().contains(q))
            .toList();
      }

      await _cache(cacheKey, performers.map((e) => e.toJson()).toList());
      return performers;
    } catch (_) {
      // fall through to cache
    }

    // Offline / error fallback
    try {
      final cached = await _readCache(cacheKey);
      if (cached is List) {
        return cached
            .map((row) => Performer.fromJson(Map<String, dynamic>.from(row)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> submitVote({
    required String performerId,
    required String eventId,
    required int score,
    Duration cooldown = const Duration(seconds: 15),
  }) async {
    if (score < 1 || score > 5) {
      throw Exception('Invalid score');
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Please sign in');
    }

    final now = DateTime.now();
    final recent = await _supabase
        .from('votes')
        .select('voted_at')
        .eq('user_id', userId)
        .order('voted_at', ascending: false)
        .limit(1);
    if ((recent as List).isNotEmpty) {
      final latestVote = DateTime.parse(recent.first['voted_at'] as String);
      if (now.difference(latestVote) < cooldown) {
        throw Exception('Please wait before submitting another vote');
      }
    }

    final existing = await _supabase
        .from('votes')
        .select('id')
        .eq('user_id', userId)
        .eq('performer_id', performerId)
        .eq('event_id', eventId)
        .limit(1);
    if ((existing as List).isNotEmpty) {
      throw Exception('You already voted for this performer in this event');
    }

    // Enforce votes_per_user limit
    try {
      final eventData = await _supabase
          .from('events')
          .select('votes_per_user, voting_deadline, expires_at')
          .eq('id', eventId)
          .single();
      final limit = eventData['votes_per_user'] as int? ?? 1;

      // Check voting deadline
      final votingDeadlineStr = eventData['voting_deadline'] as String?;
      if (votingDeadlineStr != null) {
        final deadline = DateTime.tryParse(votingDeadlineStr);
        if (deadline != null && now.isAfter(deadline)) {
          throw Exception('Voting has closed for this event');
        }
      }

      // Check event expiry
      final expiresAtStr = eventData['expires_at'] as String?;
      if (expiresAtStr != null) {
        final expiry = DateTime.tryParse(expiresAtStr);
        if (expiry != null && now.isAfter(expiry)) {
          throw Exception('This event has expired');
        }
      }

      if (limit > 0) {
        final userVotesInEvent = await _supabase
            .from('votes')
            .select('id')
            .eq('user_id', userId)
            .eq('event_id', eventId);
        final usedVotes = (userVotesInEvent as List).length;
        if (usedVotes >= limit) {
          throw Exception(
            'You have used all $limit vote${limit == 1 ? '' : 's'} for this event',
          );
        }
      }
    } catch (e) {
      if (e.toString().contains('vote')) rethrow;
    }

    await _supabase.from('votes').insert({
      'user_id': userId,
      'performer_id': performerId,
      'event_id': eventId,
      'score': score,
      'voted_at': now.toIso8601String(),
    });

    // Notify the voter
    await _supabase.from('notifications').insert({
      'user_id': userId,
      'title': 'Vote Confirmed ✅',
      'message': 'Your vote (score: $score/5) has been submitted successfully.',
      'type': 'success',
    });

    // Notify the performer they received a vote
    try {
      await _supabase.from('notifications').insert({
        'user_id': performerId,
        'title': 'You received a vote! 🗳️',
        'message': 'Someone voted for you with a score of $score/5. Keep it up!',
        'type': 'info',
      });
    } catch (_) {} // non-fatal
  }

  Future<void> submitFeedback({
    required String performerId,
    required String eventId,
    required int rating,
    required String comment,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Please sign in');
    if (rating < 1 || rating > 5) throw Exception('Rating must be 1-5');
    if (comment.trim().length < 2) throw Exception('Comment is too short');

    await _supabase.from('feedback').insert({
      'user_id': userId,
      'performer_id': performerId,
      'event_id': eventId,
      'rating': rating,
      'comment': comment.trim(),
      'is_public': true,
    });

    // Notify the performer they received feedback
    try {
      final stars = '⭐' * rating;
      await _supabase.from('notifications').insert({
        'user_id': performerId,
        'title': 'New feedback received! $stars',
        'message': comment.trim().length > 60
            ? '${comment.trim().substring(0, 60)}...'
            : comment.trim(),
        'type': 'info',
      });
    } catch (_) {} // non-fatal
  }

  /// Get all feedback received by a performer (for their own view)
  Future<List<Map<String, dynamic>>> getMyFeedback(String performerId) async {
    try {
      final res = await _supabase
          .from('feedback')
          .select('id, rating, comment, created_at, event_id, events(title)')
          .eq('performer_id', performerId)
          .order('created_at', ascending: false);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Send a broadcast notification to all users (admin only)
  Future<void> sendBroadcastNotification({
    required String title,
    required String message,
    String type = 'info',
    String? targetRole, // null = all users
  }) async {
    try {
      var query = _supabase.from('users').select('id');
      if (targetRole != null) {
        query = query.eq('role', targetRole);
      }
      final users = await query;
      final notifications = (users as List).map((u) => {
        'user_id': u['id'],
        'title': title,
        'message': message,
        'type': type,
      }).toList();
      if (notifications.isNotEmpty) {
        await _supabase.from('notifications').insert(notifications);
      }
    } catch (e) {
      throw Exception('Failed to send notification: $e');
    }
  }

  Future<List<Feedback>> getFeedbackForPerformer({
    required String performerId,
    required String eventId,
  }) async {
    final response = await _supabase
        .from('feedback')
        .select()
        .eq('performer_id', performerId)
        .eq('event_id', eventId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => Feedback.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> deleteFeedback(String feedbackId) async {
    await _supabase.from('feedback').delete().eq('id', feedbackId);
  }

  Stream<List<AppNotification>> notificationsStream(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((row) => AppNotification.fromJson(Map<String, dynamic>.from(row)))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<Vote>> votesStream(String eventId) {
    return _supabase
        .from('votes')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .map(
          (rows) => rows
              .map((row) => Vote.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  Future<Map<String, dynamic>> adminAnalytics() async {
    final users = await _supabase.from('users').select('id, role');
    final votes = await _supabase.from('votes').select('id, performer_id, score');
    final performers = await _supabase
        .from('performers')
        .select('id, talent_type, users!inner(name,email)');

    final usersList = (users as List).cast<Map<String, dynamic>>();
    final votesList = (votes as List).cast<Map<String, dynamic>>();
    final performerRows = (performers as List).cast<Map<String, dynamic>>();

    final votesByPerformer = <String, int>{};
    for (final row in votesList) {
      final performerId = row['performer_id'] as String;
      votesByPerformer[performerId] = (votesByPerformer[performerId] ?? 0) + 1;
    }

    final topPerformers = performerRows.map((p) {
      final user = Map<String, dynamic>.from(p['users'] as Map);
      final id = p['id'] as String;
      return {
        'id': id,
        'name': user['name'] ?? user['email'] ?? 'Unknown',
        'votes': votesByPerformer[id] ?? 0,
        'category': p['talent_type'] ?? 'other',
      };
    }).toList()
      ..sort((a, b) => (b['votes'] as int).compareTo(a['votes'] as int));

    final categoryVotes = <String, int>{};
    for (final performer in topPerformers) {
      final category = performer['category'] as String;
      categoryVotes[category] = (categoryVotes[category] ?? 0) + (performer['votes'] as int);
    }

    return {
      'totalUsers': usersList.length,
      'totalVotes': votesList.length,
      'activeUsers': usersList.where((u) => u['role'] == 'student').length,
      'topPerformers': topPerformers.take(5).toList(),
      'votesPerCategory': categoryVotes,
    };
  }
}
