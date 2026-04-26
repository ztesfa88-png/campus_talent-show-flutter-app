import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/vote.dart';
import '../../data/models/notification.dart';
import '../../data/models/event.dart';
import '../../core/providers/auth_provider.dart';

// ── Realtime Service ──────────────────────────────────────────────────────────

class RealtimeService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, RealtimeChannel> _channels = {};

  RealtimeChannel subscribeToVotes(
      String eventId, void Function(Vote) onNewVote) {
    final name = 'votes_$eventId';
    if (_channels.containsKey(name)) return _channels[name]!;

    final channel = _supabase
        .channel(name)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'votes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (payload) {
            try {
              final vote =
                  Vote.fromJson(Map<String, dynamic>.from(payload.newRecord));
              onNewVote(vote);
            } catch (e) {
              debugPrint('RealtimeService vote parse error: $e');
            }
          },
        )
        .subscribe();

    _channels[name] = channel;
    return channel;
  }

  RealtimeChannel subscribeToNotifications(
      String userId, void Function(AppNotification) onNew) {
    final name = 'notifications_$userId';
    if (_channels.containsKey(name)) return _channels[name]!;

    final channel = _supabase
        .channel(name)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            try {
              final n = AppNotification.fromJson(
                  Map<String, dynamic>.from(payload.newRecord));
              onNew(n);
            } catch (e) {
              debugPrint('RealtimeService notification parse error: $e');
            }
          },
        )
        .subscribe();

    _channels[name] = channel;
    return channel;
  }

  RealtimeChannel subscribeToEvents(void Function(Event) onChanged) {
    const name = 'events_all';
    if (_channels.containsKey(name)) return _channels[name]!;

    final channel = _supabase
        .channel(name)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (payload) {
            try {
              final record = payload.newRecord.isNotEmpty
                  ? payload.newRecord
                  : payload.oldRecord;
              if (record.isNotEmpty) {
                final event =
                    Event.fromJson(Map<String, dynamic>.from(record));
                onChanged(event);
              }
            } catch (e) {
              debugPrint('RealtimeService event parse error: $e');
            }
          },
        )
        .subscribe();

    _channels[name] = channel;
    return channel;
  }

  void unsubscribe(String channelName) {
    _channels[channelName]?.unsubscribe();
    _channels.remove(channelName);
  }

  void unsubscribeAll() {
    for (final ch in _channels.values) {
      ch.unsubscribe();
    }
    _channels.clear();
  }

  int get activeChannelsCount => _channels.length;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService();
  ref.onDispose(service.unsubscribeAll);
  return service;
});

/// Stream of new notifications for the current user
final realtimeNotificationsProvider =
    StreamProvider<AppNotification>((ref) async* {
  final authState = ref.watch(authStateProvider);
  final userId = authState.user?.id;
  if (userId == null) return;

  final controller = StreamController<AppNotification>.broadcast();
  final service = ref.watch(realtimeServiceProvider);
  service.subscribeToNotifications(userId, controller.add);

  ref.onDispose(() {
    service.unsubscribe('notifications_$userId');
    controller.close();
  });

  yield* controller.stream;
});

/// Stream of new votes for a given event
final realtimeVotesProvider =
    StreamProvider.family<Vote, String>((ref, eventId) async* {
  final controller = StreamController<Vote>.broadcast();
  final service = ref.watch(realtimeServiceProvider);
  service.subscribeToVotes(eventId, controller.add);

  ref.onDispose(() {
    service.unsubscribe('votes_$eventId');
    controller.close();
  });

  yield* controller.stream;
});

/// Stream of event changes
final realtimeEventsProvider = StreamProvider<Event>((ref) async* {
  final controller = StreamController<Event>.broadcast();
  final service = ref.watch(realtimeServiceProvider);
  service.subscribeToEvents(controller.add);

  ref.onDispose(() {
    service.unsubscribe('events_all');
    controller.close();
  });

  yield* controller.stream;
});
