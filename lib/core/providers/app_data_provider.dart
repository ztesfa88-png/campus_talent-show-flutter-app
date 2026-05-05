import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/models/event.dart';
import '../../data/models/performer.dart';
import '../../data/services/app_data_service.dart';

/// True when the device has no network connectivity.
final isOfflineProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.contains(ConnectivityResult.none),
  );
});

final appDataServiceProvider = Provider<AppDataService>((ref) {
  return AppDataService();
});

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('events')
        .select()
        .order('event_date', ascending: true);
    return (response as List)
        .map((row) => Event.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  } catch (_) {
    return ref.watch(appDataServiceProvider).getEvents();
  }
});

class PerformerFilter {
  final String? eventId;
  final String search;
  final TalentType? talentType;

  const PerformerFilter({
    this.eventId,
    this.search = '',
    this.talentType,
  });
}

final performerFilterProvider = StateProvider<PerformerFilter>((ref) {
  return const PerformerFilter();
});

final performersProvider = FutureProvider<List<Performer>>((ref) async {
  final filter = ref.watch(performerFilterProvider);
  final supabase = Supabase.instance.client;

  // If an event is selected, only show performers registered for it
  List<String>? registeredIds;
  if (filter.eventId != null) {
    final regs = await supabase
        .from('event_registrations')
        .select('performer_id')
        .eq('event_id', filter.eventId!)
        .neq('status', 'rejected');
    registeredIds = (regs as List).map((r) => r['performer_id'] as String).toList();
    if (registeredIds.isEmpty) return [];
  }

  var query = supabase
      .from('performers')
      .select('id, bio, talent_type, experience_level, social_links, avatar_url, approval_status, created_at, updated_at')
      .eq('approval_status', 'approved');

  if (registeredIds != null) {
    query = query.inFilter('id', registeredIds);
  }

  if (filter.talentType != null) {
    query = query.eq('talent_type', filter.talentType!.value);
  }

  final perfRows = (await query as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();

  if (perfRows.isEmpty) return [];

  final ids = perfRows.map((r) => r['id'] as String).toList();

  // Fetch user names and vote stats in parallel
  final results = await Future.wait([
    supabase.from('users').select('id, email, name, role').inFilter('id', ids),
    supabase
        .from('votes')
        .select('performer_id, score')
        .inFilter('performer_id', ids),
  ]);

  final userRows = (results[0] as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  final voteRows = (results[1] as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();

  final userMap = {for (final u in userRows) u['id'] as String: u};

  // Compute per-performer vote stats
  final voteScores = <String, List<int>>{};
  for (final v in voteRows) {
    final pid = v['performer_id'] as String;
    voteScores.putIfAbsent(pid, () => []).add(v['score'] as int);
  }

  var performers = perfRows.map((row) {
    final pid = row['id'] as String;
    final user = userMap[pid] ?? <String, dynamic>{
      'id': pid, 'email': '', 'name': null, 'role': 'performer',
    };
    final scores = voteScores[pid] ?? [];
    final avg = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    return Performer.fromJson(<String, dynamic>{
      ...user,
      ...row,
      'average_score': avg,
      'vote_count': scores.length,
    });
  }).toList();

  if (filter.search.trim().isNotEmpty) {
    final q = filter.search.trim().toLowerCase();
    performers = performers
        .where((p) => (p.name ?? p.email).toLowerCase().contains(q))
        .toList();
  }

  // Sort by composite score: votes * 0.6 + avgScore * 0.4 (normalised to 5)
  performers.sort((a, b) {
    final scoreA = a.voteCount * 0.6 + (a.averageScore / 5.0) * 0.4;
    final scoreB = b.voteCount * 0.6 + (b.averageScore / 5.0) * 0.4;
    return scoreB.compareTo(scoreA);
  });

  return performers;
});
