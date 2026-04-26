import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/event.dart';
import '../../data/models/performer.dart';
import '../../data/services/app_data_service.dart';

final appDataServiceProvider = Provider<AppDataService>((ref) {
  return AppDataService();
});

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  // Always fetch fresh from Supabase — never serve stale SQLite cache for events
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
    // Offline fallback — use AppDataService which reads SQLite cache
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

  // If an event is selected, only show performers registered for it (pending or approved, not rejected)
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
  final userRows = (await supabase
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

  if (filter.search.trim().isNotEmpty) {
    final q = filter.search.trim().toLowerCase();
    performers = performers
        .where((p) => (p.name ?? p.email).toLowerCase().contains(q))
        .toList();
  }

  return performers;
});
