import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import '../models/feedback.dart';
import '../models/notification.dart';
import '../models/performer.dart';
import '../models/vote.dart';

// On non-Web platforms we use SQLite. Import conditionally via a wrapper.
import 'cache_store.dart';

// ---------------------------------------------------------------------------
// Cache TTL
// ---------------------------------------------------------------------------
const _cacheTtl = Duration(hours: 24);

class AppDataService {
  AppDataService()
      : _supabase = Supabase.instance.client,
        _connectivity = Connectivity(),
        _store = CacheStore();

  final SupabaseClient _supabase;
  final Connectivity _connectivity;
  final CacheStore _store;

  // ── Connectivity ──────────────────────────────────────────────────────────

  Future<bool> isOnline() async {
    if (kIsWeb) {
      // connectivity_plus on Web always returns none — assume online
      return true;
    }
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────

  Future<void> _cache(String key, Object value) =>
      _store.write(key, jsonEncode(value));

  Future<dynamic> _readCache(String key, {bool ignoreExpiry = false}) async {
    final entry = await _store.read(key);
    if (entry == null) return null;
    if (!ignoreExpiry) {
      final age = DateTime.now().millisecondsSinceEpoch - entry.updatedAt;
      if (age > _cacheTtl.inMilliseconds) return null;
    }
    return jsonDecode(entry.payload);
  }

  Future<dynamic> _readCacheStale(String key) =>
      _readCache(key, ignoreExpiry: true);

  // ── Offline queue ─────────────────────────────────────────────────────────

  Future<void> _enqueue(String actionType, Map<String, dynamic> payload) =>
      _store.enqueue(actionType, jsonEncode(payload));

  Future<List<Map<String, dynamic>>> getPendingActions() =>
      _store.pendingActions();

  Future<int> getPendingCount() => _store.pendingCount();

  Future<void> _dequeue(int id) => _store.dequeue(id);

  Future<void> _incrementRetry(int id) => _store.incrementRetry(id);

  /// Sync all queued votes and feedback to Supabase.
  Future<int> syncPendingActions() async {
    if (!await isOnline()) return 0;
    final pending = await getPendingActions();
    int synced = 0;

    for (final row in pending) {
      final id = row['id'] as int;
      final type = row['action_type'] as String;
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      final retries = row['retry_count'] as int;

      if (retries >= 5) {
        await _dequeue(id);
        continue;
      }

      try {
        if (type == 'vote') {
          await _syncVote(payload);
        } else if (type == 'feedback') {
          await _syncFeedback(payload);
        }
        await _dequeue(id);
        synced++;
      } catch (_) {
        await _incrementRetry(id);
      }
    }
    return synced;
  }

  Future<void> _syncVote(Map<String, dynamic> p) async {
    final userId = p['user_id'] as String;
    final performerId = p['performer_id'] as String;
    final eventId = p['event_id'] as String;
    final score = p['score'] as int;

    final existing = await _supabase
        .from('votes')
        .select('id')
        .eq('user_id', userId)
        .eq('performer_id', performerId)
        .eq('event_id', eventId)
        .limit(1);
    if ((existing as List).isNotEmpty) return;

    await _supabase.from('votes').insert({
      'user_id': userId,
      'performer_id': performerId,
      'event_id': eventId,
      'score': score,
      'voted_at': p['voted_at'] as String,
    });

    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Vote Synced ✅',
        'message': 'Your offline vote (score: $score/5) has been submitted.',
        'type': 'success',
        'data': {'event_id': eventId, 'deep_link': 'leaderboard'},
      });
      await _supabase.from('notifications').insert({
        'user_id': performerId,
        'title': 'You received a vote! 🗳️',
        'message': 'Someone voted for you with a score of $score/5.',
        'type': 'info',
        'data': {'event_id': eventId, 'deep_link': 'results'},
      });
    } catch (_) {}
  }

  Future<void> _syncFeedback(Map<String, dynamic> p) async {
    await _supabase.from('feedback').insert({
      'user_id': p['user_id'],
      'performer_id': p['performer_id'],
      'event_id': p['event_id'],
      'rating': p['rating'],
      'comment': p['comment'],
      'is_public': true,
    });

    try {
      final rating = p['rating'] as int;
      final comment = p['comment'] as String;
      final stars = '⭐' * rating;
      await _supabase.from('notifications').insert({
        'user_id': p['performer_id'],
        'title': 'New feedback received! $stars',
        'message':
            comment.length > 60 ? '${comment.substring(0, 60)}...' : comment,
        'type': 'info',
        'data': {'event_id': p['event_id'], 'deep_link': 'results'},
      });
    } catch (_) {}
  }

  // ── Performer cache helpers (called by provider) ──────────────────────────

  Future<void> cachePerformers(
      dynamic filter, List<Performer> performers) async {
    final key = _performerKey(filter);
    await _cache(key, performers.map((e) => e.toJson()).toList());
  }

  Future<List<Performer>> getCachedPerformers(dynamic filter) async {
    final key = _performerKey(filter);

    final fresh = await _readCache(key);
    if (fresh is List && fresh.isNotEmpty) {
      return fresh
          .map((r) => Performer.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }
    final stale = await _readCacheStale(key);
    if (stale is List && stale.isNotEmpty) {
      return stale
          .map((r) => Performer.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }
    // Last resort: try the "all performers" cache
    final eventId = (filter as dynamic).eventId as String?;
    final search = (filter as dynamic).search as String;
    final talentType = (filter as dynamic).talentType;
    if (eventId != null || search.isNotEmpty || talentType != null) {
      return getCachedPerformers(_NullFilter());
    }
    return [];
  }

  String _performerKey(dynamic filter) {
    final eventId = (filter as dynamic).eventId as String?;
    final search = (filter as dynamic).search as String;
    final talentType = (filter as dynamic).talentType;
    return 'performers_${eventId ?? 'all'}_${search}_${talentType?.value ?? ''}';
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Future<List<Event>> getEvents() async {
    const key = 'events_all';
    try {
      if (await isOnline()) {
        final response = await _supabase
            .from('events')
            .select()
            .order('event_date', ascending: true);
        final events = (response as List)
            .map((row) => Event.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        await _cache(key, events.map((e) => e.toJson()).toList());
        return events;
      }
    } catch (_) {}

    final cached = await _readCache(key);
    if (cached is List) {
      return cached
          .map((r) => Event.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }
    final stale = await _readCacheStale(key);
    if (stale is List) {
      return stale
          .map((r) => Event.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }
    return [];
  }

  // ── Performers ────────────────────────────────────────────────────────────

  Future<List<Performer>> getPerformers({
    String? eventId,
    String? search,
    TalentType? talentType,
  }) async {
    final key =
        'performers_${eventId ?? 'all'}_${search ?? ''}_${talentType?.value ?? ''}';
    try {
      var q = _supabase
          .from('performers')
          .select(
              'id, bio, talent_type, experience_level, social_links, avatar_url, approval_status, created_at, updated_at')
          .eq('approval_status', 'approved');
      if (talentType != null) q = q.eq('talent_type', talentType.value);

      final perfRows = (await q as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      if (perfRows.isEmpty) {
        await _cache(key, <dynamic>[]);
        return [];
      }

      final ids = perfRows.map((r) => r['id'] as String).toList();
      final userRows = (await _supabase
              .from('users')
              .select('id, email, name, role')
              .inFilter('id', ids) as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final userMap = {for (final u in userRows) u['id'] as String: u};

      var performers = perfRows.map((row) {
        final user = userMap[row['id'] as String] ??
            <String, dynamic>{
              'id': row['id'],
              'email': '',
              'name': null,
              'role': 'performer',
            };
        return Performer.fromJson(<String, dynamic>{...user, ...row});
      }).toList();

      if (search != null && search.trim().isNotEmpty) {
        final sq = search.trim().toLowerCase();
        performers = performers
            .where((p) => (p.name ?? p.email).toLowerCase().contains(sq))
            .toList();
      }

      await _cache(key, performers.map((e) => e.toJson()).toList());
      return performers;
    } catch (_) {}

    final cached = await _readCache(key);
    if (cached is List) {
      return cached
          .map((r) => Performer.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }
    final stale = await _readCacheStale(key);
    if (stale is List) {
      return stale
          .map((r) => Performer.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }
    return [];
  }

  // ── Voting ────────────────────────────────────────────────────────────────

  Future<VoteResult> submitVoteWithOfflineSupport({
    required String performerId,
    required String eventId,
    required int score,
    required String userId,
  }) async {
    if (score < 1 || score > 5) throw Exception('Score must be 1–5');

    final online = await isOnline();

    if (!online) {
      final pending = await getPendingActions();
      final alreadyQueued = pending.any((r) {
        if (r['action_type'] != 'vote') return false;
        final p =
            jsonDecode(r['payload'] as String) as Map<String, dynamic>;
        return p['performer_id'] == performerId &&
            p['event_id'] == eventId &&
            p['user_id'] == userId;
      });
      if (alreadyQueued) {
        throw Exception('You already have a queued vote for this performer');
      }

      await _enqueue('vote', {
        'user_id': userId,
        'performer_id': performerId,
        'event_id': eventId,
        'score': score,
        'voted_at': DateTime.now().toIso8601String(),
      });
      return VoteResult.queued;
    }

    await submitVote(
        performerId: performerId, eventId: eventId, score: score);
    return VoteResult.submitted;
  }

  Future<FeedbackResult> submitFeedbackWithOfflineSupport({
    required String performerId,
    required String eventId,
    required int rating,
    required String comment,
    required String userId,
  }) async {
    if (rating < 1 || rating > 5) throw Exception('Rating must be 1–5');
    if (comment.trim().length < 2) throw Exception('Comment is too short');

    final online = await isOnline();

    if (!online) {
      await _enqueue('feedback', {
        'user_id': userId,
        'performer_id': performerId,
        'event_id': eventId,
        'rating': rating,
        'comment': comment.trim(),
      });
      return FeedbackResult.queued;
    }

    await submitFeedback(
        performerId: performerId,
        eventId: eventId,
        rating: rating,
        comment: comment);
    return FeedbackResult.submitted;
  }

  Future<void> submitVote({
    required String performerId,
    required String eventId,
    required int score,
    Duration cooldown = const Duration(seconds: 15),
  }) async {
    if (score < 1 || score > 5) throw Exception('Invalid score');
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Please sign in');

    final now = DateTime.now();
    final recent = await _supabase
        .from('votes')
        .select('voted_at')
        .eq('user_id', userId)
        .order('voted_at', ascending: false)
        .limit(1);
    if ((recent as List).isNotEmpty) {
      final latestVote =
          DateTime.parse(recent.first['voted_at'] as String);
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

    try {
      final eventData = await _supabase
          .from('events')
          .select('votes_per_user, voting_deadline, expires_at')
          .eq('id', eventId)
          .single();
      final limit = eventData['votes_per_user'] as int? ?? 1;

      final votingDeadlineStr = eventData['voting_deadline'] as String?;
      if (votingDeadlineStr != null) {
        final deadline = DateTime.tryParse(votingDeadlineStr);
        if (deadline != null && now.isAfter(deadline)) {
          throw Exception('Voting has closed for this event');
        }
      }

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
              'You have used all $limit vote${limit == 1 ? '' : 's'} for this event');
        }
      }
    } catch (e) {
      if (e.toString().contains('vote') ||
          e.toString().contains('Voting') ||
          e.toString().contains('expired')) rethrow;
    }

    await _supabase.from('votes').insert({
      'user_id': userId,
      'performer_id': performerId,
      'event_id': eventId,
      'score': score,
      'voted_at': now.toIso8601String(),
    });
  }

  Future<void> submitVoteNotification({
    required String userId,
    required String performerId,
    required int score,
    required String eventId,
  }) async {
    await _supabase.from('notifications').insert({
      'user_id': userId,
      'title': 'Vote Confirmed ✅',
      'message':
          'Your vote (score: $score/5) has been submitted successfully.',
      'type': 'success',
      'data': {'event_id': eventId, 'deep_link': 'leaderboard'},
    });
    try {
      await _supabase.from('notifications').insert({
        'user_id': performerId,
        'title': 'You received a vote! 🗳️',
        'message':
            'Someone voted for you with a score of $score/5. Keep it up!',
        'type': 'info',
        'data': {'event_id': eventId, 'deep_link': 'results'},
      });
    } catch (_) {}
  }

  // ── Feedback ──────────────────────────────────────────────────────────────

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

    try {
      final stars = '⭐' * rating;
      await _supabase.from('notifications').insert({
        'user_id': performerId,
        'title': 'New feedback received! $stars',
        'message': comment.trim().length > 60
            ? '${comment.trim().substring(0, 60)}...'
            : comment.trim(),
        'type': 'info',
        'data': {'event_id': eventId, 'deep_link': 'results'},
      });
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getMyFeedback(
      String performerId) async {
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

  Future<void> sendBroadcastNotification({
    required String title,
    required String message,
    String type = 'info',
    String? targetRole,
  }) async {
    try {
      var query = _supabase.from('users').select('id');
      if (targetRole != null) {
        query = query.eq('role', targetRole);
      }
      final users = await query;
      final notifications = (users as List)
          .map((u) => {
                'user_id': u['id'],
                'title': title,
                'message': message,
                'type': type,
              })
          .toList();
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

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<AppNotification>> notificationsStream(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((row) => AppNotification.fromJson(
                  Map<String, dynamic>.from(row)))
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
              .map((row) =>
                  Vote.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> adminAnalytics() async {
    final users = await _supabase.from('users').select('id, role');
    final votes =
        await _supabase.from('votes').select('id, performer_id, score');
    final performers = await _supabase
        .from('performers')
        .select(
            'id, talent_type, approval_status, users!inner(name,email)');
    final events = await _supabase.from('events').select('id, status');

    final usersList = (users as List).cast<Map<String, dynamic>>();
    final votesList = (votes as List).cast<Map<String, dynamic>>();
    final performerRows = (performers as List).cast<Map<String, dynamic>>();
    final eventsList = (events as List).cast<Map<String, dynamic>>();

    final votesByPerformer = <String, int>{};
    for (final row in votesList) {
      final pid = row['performer_id'] as String;
      votesByPerformer[pid] = (votesByPerformer[pid] ?? 0) + 1;
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
      ..sort((a, b) =>
          (b['votes'] as int).compareTo(a['votes'] as int));

    final categoryVotes = <String, int>{};
    for (final performer in topPerformers) {
      final cat = performer['category'] as String;
      categoryVotes[cat] =
          (categoryVotes[cat] ?? 0) + (performer['votes'] as int);
    }

    final eventStatusCounts = <String, int>{};
    for (final e in eventsList) {
      final s = e['status'] as String? ?? 'upcoming';
      eventStatusCounts[s] = (eventStatusCounts[s] ?? 0) + 1;
    }

    return {
      'totalUsers': usersList.length,
      'totalVotes': votesList.length,
      'activeUsers':
          usersList.where((u) => u['role'] == 'student').length,
      'totalPerformers': performerRows.length,
      'pendingPerformers': performerRows
          .where((p) => p['approval_status'] == 'pending')
          .length,
      'totalEvents': eventsList.length,
      'eventStatusCounts': eventStatusCounts,
      'topPerformers': topPerformers.take(5).toList(),
      'votesPerCategory': categoryVotes,
    };
  }
}

// ── Result enums ──────────────────────────────────────────────────────────────

enum VoteResult { submitted, queued }
enum FeedbackResult { submitted, queued }

// ── Internal helpers ──────────────────────────────────────────────────────────

class _NullFilter {
  String? get eventId => null;
  String get search => '';
  dynamic get talentType => null;
}
