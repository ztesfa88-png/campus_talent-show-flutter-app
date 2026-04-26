import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_data_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/event.dart';
import '../../../data/models/performer.dart';

// -----------------------------------------------------------------------------
// STUDENT APP SHELL
// -----------------------------------------------------------------------------

class StudentAppShell extends ConsumerStatefulWidget {
  const StudentAppShell({super.key});
  @override
  ConsumerState<StudentAppShell> createState() => _StudentAppShellState();
}

class _StudentAppShellState extends ConsumerState<StudentAppShell> {
  int _tab = 0;
  final _searchCtrl = TextEditingController();
  TalentType? _filterType;
  Event? _selectedEvent;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final tabs = [
      _HomeTab(searchCtrl: _searchCtrl, filterType: _filterType, selectedEvent: _selectedEvent,
          onTypeChanged: (v) => setState(() => _filterType = v),
          onEventChanged: (v) => setState(() => _selectedEvent = v)),
      _VoteTab(selectedEvent: _selectedEvent),
      _LeaderboardTab(event: _selectedEvent),
      _NotificationsTab(userId: user.id),
      _ProfileTab(user: user),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: tabs[_tab],
      bottomNavigationBar: _BottomNav(current: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

// --- Bottom Navigation --------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.how_to_vote_rounded, Icons.how_to_vote_outlined, 'Vote'),
    (Icons.leaderboard_rounded, Icons.leaderboard_outlined, 'Ranks'),
    (Icons.notifications_rounded, Icons.notifications_outlined, 'Alerts'),
    (Icons.person_rounded, Icons.person_outlined, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final sel = current == i;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFFEEF2FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(sel ? item.$1 : item.$2, color: sel ? AppColors.primary : AppColors.textHint, size: 22),
                    const SizedBox(height: 2),
                    Text(item.$3, style: TextStyle(color: sel ? AppColors.primary : AppColors.textHint, fontSize: 10, fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// --- Home Tab -----------------------------------------------------------------

class _HomeTab extends ConsumerWidget {
  const _HomeTab({
    required this.searchCtrl, required this.filterType, required this.selectedEvent,
    required this.onTypeChanged, required this.onEventChanged,
  });
  final TextEditingController searchCtrl;
  final TalentType? filterType;
  final Event? selectedEvent;
  final ValueChanged<TalentType?> onTypeChanged;
  final ValueChanged<Event?> onEventChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final performers = ref.watch(performersProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(eventsProvider);
        ref.invalidate(performersProvider);
        await Future.wait([
          ref.read(eventsProvider.future).catchError((_) => <Event>[]),
          ref.read(performersProvider.future).catchError((_) => <Performer>[]),
        ]);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Discover', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                        const Text('Campus Talent', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.circle, color: Color(0xFF4ADE80), size: 7),
                          SizedBox(width: 5),
                          Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        style: const TextStyle(color: AppColors.textMain, fontSize: 14),
                        onChanged: (_) {
                          ref.read(performerFilterProvider.notifier).state = PerformerFilter(
                            eventId: selectedEvent?.id, search: searchCtrl.text.trim(), talentType: filterType,
                          );
                        },
                        decoration: InputDecoration(
                          hintText: 'Search performers...',
                          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () { searchCtrl.clear(); ref.read(performerFilterProvider.notifier).state = PerformerFilter(eventId: selectedEvent?.id, talentType: filterType); },
                                  child: const Icon(Icons.close_rounded, color: AppColors.textHint, size: 18))
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          filled: false,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                events.when(
                  data: (items) {
                    if (items.isEmpty) return const SizedBox.shrink();
                    final defaultEvent = items.firstWhere((e) => e.isActive, orElse: () => items.first);
                    final cur = selectedEvent ?? defaultEvent;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (selectedEvent == null && items.isNotEmpty) onEventChanged(defaultEvent);
                    });
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Event>(
                          value: cur, isExpanded: true,
                          style: const TextStyle(color: AppColors.textMain, fontSize: 14),
                          dropdownColor: AppColors.surface,
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textHint),
                          items: items.map((e) => DropdownMenuItem(value: e, child: Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: e.isActive ? AppColors.accent : AppColors.textHint, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: e.isActive ? const Color(0xFFDCFCE7) : AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(e.status.value, style: TextStyle(color: e.isActive ? AppColors.accent : AppColors.textHint, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          ]))).toList(),
                          onChanged: (v) {
                            onEventChanged(v);
                            ref.read(performerFilterProvider.notifier).state = PerformerFilter(eventId: v?.id, search: searchCtrl.text.trim(), talentType: filterType);
                          },
                        ),
                      ),
                    );
                  },
                  loading: () => _Skel(height: 52),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(label: 'All', selected: filterType == null, onTap: () {
                        onTypeChanged(null);
                        ref.read(performerFilterProvider.notifier).state = PerformerFilter(eventId: selectedEvent?.id, search: searchCtrl.text.trim());
                      }),
                      ...TalentType.values.map((t) => _FilterChip(
                        label: _talentLabel(t), selected: filterType == t,
                        onTap: () {
                          onTypeChanged(t);
                          ref.read(performerFilterProvider.notifier).state = PerformerFilter(eventId: selectedEvent?.id, search: searchCtrl.text.trim(), talentType: t);
                        },
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Top Performers', style: TextStyle(color: AppColors.textMain, fontSize: 18, fontWeight: FontWeight.w800)),
                  performers.when(
                    data: (items) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                      child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ]),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          performers.when(
            data: (items) {
              if (items.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: Column(children: [
                      Text('\u{1F3AD}', style: TextStyle(fontSize: 52)),
                      SizedBox(height: 14),
                      Text('No performers found', style: TextStyle(color: AppColors.textSub, fontSize: 15, fontWeight: FontWeight.w500)),
                    ])),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PerformerCard(performer: items[i], event: selectedEvent, rank: i + 1),
                  ),
                  childCount: items.length,
                )),
              );
            },
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, _) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _Skel(height: 92)),
                childCount: 4,
              )),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                  const SizedBox(height: 12),
                  Text('Error: $err', style: const TextStyle(color: AppColors.textSub), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(performersProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _talentEmojis = {'music': '\u{1F3B5}', 'dance': '\u{1F483}', 'comedy': '\u{1F602}', 'drama': '\u{1F3AD}', 'magic': '\u{2728}', 'other': '\u{2B50}'};
  String _talentLabel(TalentType t) {
    final e = _talentEmojis[t.value] ?? '\u{2B50}';
    return '$e ${t.value[0].toUpperCase()}${t.value.substring(1)}';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: selected ? AppColors.primaryGradient : null,
        color: selected ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Colors.transparent : AppColors.border),
        boxShadow: selected ? AppColors.primaryShadow : AppColors.cardShadow,
      ),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textSub, fontWeight: selected ? FontWeight.w700 : FontWeight.normal, fontSize: 12)),
    ),
  );
}

// --- Performer Card -----------------------------------------------------------

class _PerformerCard extends ConsumerWidget {
  const _PerformerCard({required this.performer, required this.event, this.rank});
  final Performer performer; final Event? event; final int? rank;

  static const _emojis = {'music': '\u{1F3B5}', 'dance': '\u{1F483}', 'comedy': '\u{1F602}', 'drama': '\u{1F3AD}', 'magic': '\u{2728}', 'other': '\u{2B50}'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emoji = _emojis[performer.talentType.value] ?? '\u{2B50}';
    final name = performer.name ?? performer.email;

    return GestureDetector(
      onTap: event == null ? null : () => showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _PerformerSheet(performer: performer, event: event!),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(18)),
              child: performer.avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        performer.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
                      ),
                    )
                  : Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
            ),
            if (rank != null && rank! <= 3)
              Positioned(
                top: -6, right: -6,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                  ),
                  child: Center(child: Text('$rank', style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900))),
                ),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(performer.talentType.value[0].toUpperCase() + performer.talentType.value.substring(1), style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
                child: Text(performer.experienceLevel.value, style: const TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.w500)),
              ),
            ]),
            const SizedBox(height: 5),
            _StarRow(4.0),
          ])),
          const SizedBox(width: 10),
          if (event != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppColors.accentShadow,
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.how_to_vote_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Vote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
              child: const Text('No event', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
            ),
        ]),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow(this.rating);
  final double rating;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
    if (i < rating.floor()) return const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 13);
    if (i < rating) return const Icon(Icons.star_half_rounded, color: Color(0xFFF59E0B), size: 13);
    return const Icon(Icons.star_border_rounded, color: Color(0xFFF59E0B), size: 13);
  }));
}

// --- Performer Detail Sheet ---------------------------------------------------

class _PerformerSheet extends ConsumerStatefulWidget {
  const _PerformerSheet({required this.performer, required this.event});
  final Performer performer; final Event event;
  @override
  ConsumerState<_PerformerSheet> createState() => _PerformerSheetState();
}

class _PerformerSheetState extends ConsumerState<_PerformerSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  int _score = 5, _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _submittingVote = false, _submittingFeedback = false;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); _commentCtrl.dispose(); super.dispose(); }

  Future<void> _submitVote() async {
    setState(() => _submittingVote = true);
    try {
      await ref.read(appDataServiceProvider).submitVote(
        performerId: widget.performer.id,
        eventId: widget.event.id,
        score: _score,
      );
      if (mounted) {
        setState(() => _submittingVote = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Vote submitted! Score: $_score/5'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submittingVote = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (_commentCtrl.text.trim().length < 2) return;
    setState(() => _submittingFeedback = true);
    try {
      await ref.read(appDataServiceProvider).submitFeedback(
        performerId: widget.performer.id,
        eventId: widget.event.id,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _submittingFeedback = false);
        _commentCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Feedback submitted!'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submittingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.performer;
    final name = p.name ?? p.email;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.primaryShadow),
              child: p.avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(p.avatarUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)))),
                    )
                  : Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: AppColors.textMain, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${p.talentType.value[0].toUpperCase()}${p.talentType.value.substring(1)} \u2022 ${p.experienceLevel.value}', style: const TextStyle(color: AppColors.textSub, fontSize: 13)),
              const SizedBox(height: 4),
              _StarRow(4.0),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Icon(Icons.close_rounded, color: AppColors.textSub, size: 18)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Container(
            height: 44,
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(22)),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(22)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSub,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [Tab(text: 'Vote'), Tab(text: 'Feedback'), Tab(text: 'About')],
            ),
          ),
        ),
        Expanded(child: TabBarView(controller: _tabCtrl, children: [
          // Vote tab
          SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.bio != null && p.bio!.isNotEmpty) ...[
              Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Text(p.bio!, style: const TextStyle(color: AppColors.textSub, fontSize: 14, height: 1.5))),
              const SizedBox(height: 20),
            ],
            const Text('Cast Your Vote', style: TextStyle(color: AppColors.textMain, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Select a score from 1 to 5', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.how_to_vote_rounded, color: AppColors.primary, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Vote limit: ${widget.event.votesPerUser} vote${widget.event.votesPerUser == 1 ? '' : 's'} per student for this event',
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
            if (widget.event.votingDeadline != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.event.isVotingOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    widget.event.isVotingOpen ? Icons.schedule_rounded : Icons.event_busy_rounded,
                    color: widget.event.isVotingOpen ? AppColors.accent : AppColors.error,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    widget.event.isVotingOpen
                        ? 'Voting closes: ${widget.event.formattedVotingDeadline!}'
                        : 'Voting closed: ${widget.event.formattedVotingDeadline!}',
                    style: TextStyle(
                      color: widget.event.isVotingOpen ? AppColors.accent : AppColors.error,
                      fontSize: 11, fontWeight: FontWeight.w600,
                    ),
                  )),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(5, (i) {
              final val = i + 1; final sel = _score == val;
              return GestureDetector(
                onTap: () => setState(() => _score = val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    gradient: sel ? AppColors.primaryGradient : null,
                    color: sel ? null : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sel ? Colors.transparent : AppColors.border),
                    boxShadow: sel ? AppColors.primaryShadow : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.star_rounded, color: sel ? Colors.white : const Color(0xFFF59E0B), size: 20),
                    Text('$val', style: TextStyle(color: sel ? Colors.white : AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 14)),
                  ]),
                ),
              );
            })),
            const SizedBox(height: 24),
            SizedBox(height: 54, width: double.infinity, child: ElevatedButton.icon(
              onPressed: _submittingVote ? null : _submitVote,
              icon: _submittingVote ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.how_to_vote_rounded),
              label: Text(_submittingVote ? 'Submitting...' : 'Submit Vote (Score: $_score/5)'),
            )),
          ])),
          // Feedback tab
          SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Leave Feedback', style: TextStyle(color: AppColors.textMain, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
              final val = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = val),
                child: Icon(_rating >= val ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF59E0B), size: 40),
              );
            })),
            const SizedBox(height: 16),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Share your thoughts about this performance...'),
            ),
            const SizedBox(height: 20),
            SizedBox(height: 54, width: double.infinity, child: ElevatedButton.icon(
              onPressed: _submittingFeedback ? null : _submitFeedback,
              icon: _submittingFeedback ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
              label: Text(_submittingFeedback ? 'Submitting...' : 'Submit Feedback'),
            )),
          ])),
          // About tab
          SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.bio != null && p.bio!.isNotEmpty) ...[
              const Text('Bio', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Text(p.bio!, style: const TextStyle(color: AppColors.textMain, fontSize: 14, height: 1.6))),
              const SizedBox(height: 16),
            ],
            const Text('Details', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _DetailRow(Icons.music_note_rounded, 'Talent', '${p.talentType.value[0].toUpperCase()}${p.talentType.value.substring(1)}'),
            _DetailRow(Icons.trending_up_rounded, 'Experience', '${p.experienceLevel.value[0].toUpperCase()}${p.experienceLevel.value.substring(1)}'),
            if (p.socialLinks.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Social Links', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...p.socialLinks.entries.map((e) => _DetailRow(Icons.link_rounded, e.key, e.value.toString())),
            ],
          ])),
        ])),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);
  final IconData icon; final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Icon(icon, color: AppColors.primary, size: 18)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
        Text(value, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ]),
  );
}

// --- Vote Tab -----------------------------------------------------------------

class _VoteTab extends ConsumerWidget {
  const _VoteTab({required this.selectedEvent});
  final Event? selectedEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performers = ref.watch(performersProvider);
    return Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Vote', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
            Text(selectedEvent?.title ?? 'Select an event in Home', style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
          ])),
          if (selectedEvent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, color: AppColors.accent, size: 7),
                SizedBox(width: 5),
                Text('Live', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 11)),
              ]),
            ),
        ]),
      ),
      if (selectedEvent == null)
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.primaryShadow), child: const Icon(Icons.how_to_vote_rounded, color: Colors.white, size: 40)),
          const SizedBox(height: 16),
          const Text('Select an event in Home\nto start voting', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSub, fontSize: 15, height: 1.5)),
        ])))
      else
        Expanded(child: performers.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('\u{1F3AD}', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 14),
                const Text('No performers yet', style: TextStyle(color: AppColors.textSub, fontSize: 15)),
              ]));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final p = items[i];
                final name = p.name ?? p.email;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
                  child: Row(children: [
                    Container(width: 52, height: 52, decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(16)),
                      child: p.avatarUrl != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(p.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)))))
                          : Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(p.talentType.value, style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                      const SizedBox(height: 3),
                      _StarRow(3.5),
                    ])),
                    GestureDetector(
                      onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _PerformerSheet(performer: p, event: selectedEvent!)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(22), boxShadow: AppColors.accentShadow),
                        child: const Text('Vote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ),
                  ]),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text('$err', style: const TextStyle(color: AppColors.textSub), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: () => ref.invalidate(performersProvider), icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ])),
        )),
    ]);
  }
}

// --- Leaderboard Tab ----------------------------------------------------------

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab({required this.event});
  final Event? event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (event == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.primaryShadow), child: const Icon(Icons.leaderboard_rounded, color: Colors.white, size: 40)),
        const SizedBox(height: 16),
        const Text('Select an event in Home\nto see rankings', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSub, fontSize: 15, height: 1.5)),
      ]));
    }

    final stream = ref.watch(appDataServiceProvider).votesStream(event!.id);
    final performersAsync = ref.watch(performersProvider);

    return Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Leaderboard', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
            Text('Live rankings by votes', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: AppColors.accent, size: 7), SizedBox(width: 5), Text('Live', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 11))])),
        ]),
      ),
      Expanded(child: StreamBuilder(
        stream: stream,
        builder: (_, snap) {
          final votes = snap.data ?? [];
          final countMap = <String, int>{};
          for (final v in votes) {
            countMap[v.performerId] = (countMap[v.performerId] ?? 0) + 1;
          }
          return performersAsync.when(
            data: (performers) {
              final ranked = performers.map((p) => (performer: p, votes: countMap[p.id] ?? 0)).toList()..sort((a, b) => b.votes.compareTo(a.votes));
              if (ranked.isEmpty) return const Center(child: Text('No performers yet', style: TextStyle(color: AppColors.textSub)));
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: ranked.length,
                itemBuilder: (_, i) {
                  final item = ranked[i];
                  const medals = ['\u{1F947}', '\u{1F948}', '\u{1F949}'];
                  final isTop = i < 3;
                  final name = item.performer.name ?? item.performer.email;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isTop ? const Color(0xFFF5F3FF) : AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isTop ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border),
                      boxShadow: isTop ? AppColors.primaryShadow : AppColors.cardShadow,
                    ),
                    child: Row(children: [
                      SizedBox(width: 36, child: Text(isTop ? medals[i] : '#${i + 1}', style: TextStyle(fontSize: isTop ? 22 : 13, color: AppColors.textMain, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Container(width: 46, height: 46, decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(14)),
                        child: item.performer.avatarUrl != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(item.performer.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)))))
                            : Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(item.performer.talentType.value, style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: isTop ? AppColors.primaryGradient : null,
                          color: isTop ? null : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${item.votes} votes', style: TextStyle(color: isTop ? Colors.white : AppColors.textSub, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ]),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (_, _) => const Center(child: Text('Unable to load', style: TextStyle(color: AppColors.textSub))),
          );
        },
      )),
    ]);
  }
}

// --- Notifications Tab --------------------------------------------------------

class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(appDataServiceProvider).notificationsStream(userId);
    return Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: const Text('Notifications', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
      ),
      Expanded(child: StreamBuilder(
        stream: stream,
        builder: (_, snap) {
          final notifications = snap.data ?? [];
          if (notifications.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)), child: const Icon(Icons.notifications_none_rounded, color: AppColors.textHint, size: 40)),
              const SizedBox(height: 16),
              const Text('No notifications yet', style: TextStyle(color: AppColors.textSub, fontSize: 15)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: notifications.length,
            itemBuilder: (_, i) {
              final n = notifications[i];
              final typeColors = <String, Color>{
                'success': AppColors.accent, 'error': AppColors.error,
                'warning': const Color(0xFFD97706), 'info': AppColors.primary,
              };
              final typeIcons = <String, IconData>{
                'success': Icons.check_circle_rounded, 'error': Icons.error_rounded,
                'warning': Icons.warning_rounded, 'info': Icons.notifications_rounded,
              };
              final type = n.type.value;
              final color = typeColors[type] ?? AppColors.primary;
              final icon = typeIcons[type] ?? Icons.notifications_rounded;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: n.isRead ? AppColors.surface : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: n.isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.25)),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: n.isRead ? null : AppColors.primaryGradient,
                      color: n.isRead ? AppColors.surfaceAlt : null,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(n.isRead ? Icons.notifications_none_rounded : icon, color: n.isRead ? AppColors.textHint : Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.title, style: TextStyle(color: AppColors.textMain, fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(n.message, style: const TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (!n.isRead) Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(height: 4),
                    Text('${n.createdAt.hour.toString().padLeft(2, '0')}:${n.createdAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                  ]),
                ]),
              );
            },
          );
        },
      )),
    ]);
  }
}

// --- Profile Tab --------------------------------------------------------------

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user?.name ?? 'Student';
    final email = user?.email ?? '';
    return ListView(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.primaryShadow),
          child: Column(children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)),
              child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: const Text('\u{1F393} Student', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Account', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 10),
        _ProfileTile(emoji: '\u{1F6E1}\u{FE0F}', title: 'Voting Security', subtitle: 'Duplicate vote prevention & cooldown active', color: AppColors.primary),
        const SizedBox(height: 10),
        _ProfileTile(emoji: '\u{1F4F6}', title: 'Offline Cache', subtitle: 'Performers & events cached for offline access', color: AppColors.secondary),
        const SizedBox(height: 10),
        _ProfileTile(emoji: '\u{1F514}', title: 'Notifications', subtitle: 'Real-time event & voting updates enabled', color: AppColors.accent),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () async {
              await ref.read(authStateProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.emoji, required this.title, required this.subtitle, required this.color});
  final String emoji, title, subtitle; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
    child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
      ])),
      const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
    ]),
  );
}

// --- Shared -------------------------------------------------------------------

class _Skel extends StatelessWidget {
  const _Skel({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(height: height, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14)));
}
