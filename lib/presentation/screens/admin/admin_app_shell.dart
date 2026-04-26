import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/app_data_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/event.dart';
import '../../../data/services/app_data_service.dart';

// -----------------------------------------------------------------------------
// ADMIN APP SHELL  � light theme, matches student/performer design
// -----------------------------------------------------------------------------

class AdminAppShell extends ConsumerStatefulWidget {
  const AdminAppShell({super.key});
  @override
  ConsumerState<AdminAppShell> createState() => _AdminAppShellState();
}

class _AdminAppShellState extends ConsumerState<AdminAppShell> {
  int _tab = 0;
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  static const _tabs = [
    (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
    (Icons.mic_rounded, Icons.mic_outlined, 'Performers'),
    (Icons.people_rounded, Icons.people_outlined, 'Users'),
    (Icons.event_rounded, Icons.event_outlined, 'Events'),
    (Icons.shield_rounded, Icons.shield_outlined, 'Admins'),
  ];

  @override
  void dispose() { _titleCtrl.dispose(); _locationCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final service = AppDataService();
    final bodies = [
      _DashboardTab(service: service),
      const _PerformersTab(),
      const _UsersTab(),
      _EventsTab(titleCtrl: _titleCtrl, locationCtrl: _locationCtrl),
      _AdminsTab(currentUser: user),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bodies[_tab],
      bottomNavigationBar: Container(
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
              children: List.generate(_tabs.length, (i) {
                final t = _tabs[i]; final sel = _tab == i;
                return GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFEEF2FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(sel ? t.$1 : t.$2, color: sel ? AppColors.primary : AppColors.textHint, size: 22),
                      const SizedBox(height: 2),
                      Text(t.$3, style: TextStyle(color: sel ? AppColors.primary : AppColors.textHint, fontSize: 9, fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Shared helpers -----------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child, this.p});
  final Widget child; final EdgeInsets? p;
  @override
  Widget build(BuildContext context) => Container(
    padding: p ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}

class _Av extends StatelessWidget {
  const _Av(this.name, {this.photoUrl});
  final String name;
  final String? photoUrl;
  static const double size = 44;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(size * 0.3)),
    child: photoUrl != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.3),
            child: Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.38))),
            ),
          )
        : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.38))),
  );
}

Widget _statusBadge(String label, Color bg, Color fg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
  child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
);

Widget _actionBtn(String label, Color bg, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]),
    child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
  ),
);

SnackBar _snack(String msg, Color color) => SnackBar(
  content: Text(msg),
  backgroundColor: color,
  behavior: SnackBarBehavior.floating,
  margin: const EdgeInsets.all(16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerStatefulWidget {
  const _DashboardTab({required this.service});
  final AppDataService service;
  @override
  ConsumerState<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<_DashboardTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.service.adminAnalytics();
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          // ── Hero Header (same style as student home) ──────────────────────
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
                    // Top row
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Welcome back,', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(user?.name ?? 'Admin', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      ])),
                      // Live badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.circle, color: Color(0xFF4ADE80), size: 7),
                          SizedBox(width: 5),
                          Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      // Sign out
                      GestureDetector(
                        onTap: () async {
                          await ref.read(authStateProvider.notifier).signOut();
                          if (context.mounted) context.go('/login');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    // Stat cards inside hero
                    if (_loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ))
                    else if (_data != null)
                      Row(children: [
                        _HeroStatCard('${_data!['totalVotes']}', 'Votes', Icons.how_to_vote_rounded),
                        const SizedBox(width: 10),
                        _HeroStatCard('${_data!['totalUsers']}', 'Users', Icons.people_rounded),
                        const SizedBox(width: 10),
                        _HeroStatCard('${_data!['activeUsers']}', 'Students', Icons.school_rounded),
                      ]),
                  ]),
                ),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_data == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(child: Column(children: [
                  const Icon(Icons.wifi_off_rounded, color: AppColors.textHint, size: 48),
                  const SizedBox(height: 12),
                  const Text('Could not load data', style: TextStyle(color: AppColors.textSub)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
                ])),
              ),
            )
          else ...[
            // ── Quick Action Cards ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Quick Actions', style: TextStyle(color: AppColors.textMain, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _QuickAction(icon: Icons.mic_rounded, label: 'Performers', color: AppColors.secondary, onTap: () {}),
                    const SizedBox(width: 10),
                    _QuickAction(icon: Icons.people_rounded, label: 'Users', color: AppColors.primary, onTap: () {}),
                    const SizedBox(width: 10),
                    _QuickAction(icon: Icons.event_rounded, label: 'Events', color: AppColors.accent, onTap: () {}),
                    const SizedBox(width: 10),
                    _QuickAction(icon: Icons.shield_rounded, label: 'Admins', color: const Color(0xFFD97706), onTap: () {}),
                  ]),
                  const SizedBox(height: 20),
                  const Text('🏆 Top Performers', style: TextStyle(color: AppColors.textMain, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                ]),
              ),
            ),

            // ── Top Performers ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final top = (_data!['topPerformers'] as List).cast<Map<String, dynamic>>();
                  if (i >= top.length) return null;
                  final item = top[i];
                  const medals = ['🥇', '🥈', '🥉'];
                  final isTop = i < 3;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isTop ? const Color(0xFFF5F3FF) : AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isTop ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border),
                        boxShadow: isTop ? AppColors.primaryShadow : AppColors.cardShadow,
                      ),
                      child: Row(children: [
                        SizedBox(width: 36, child: Text(isTop ? medals[i] : '#${i + 1}', style: TextStyle(fontSize: isTop ? 22 : 13, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        _Av(item['name'] as String),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item['name'] as String, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
                          Text(item['category'] as String, style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: isTop ? AppColors.primaryGradient : null,
                            color: isTop ? null : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${item['votes']} votes', style: TextStyle(color: isTop ? Colors.white : AppColors.textSub, fontWeight: FontWeight.w700, fontSize: 11)),
                        ),
                      ]),
                    ),
                  );
                }, childCount: (_data!['topPerformers'] as List).length),
              ),
            ),

            // ── Votes by Category ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('📊 Votes by Category', style: TextStyle(color: AppColors.textMain, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _Card(child: () {
                    final cats = (_data!['votesPerCategory'] as Map<String, dynamic>).cast<String, int>();
                    if (cats.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(child: Text('No votes yet', style: TextStyle(color: AppColors.textSub))),
                      );
                    }
                    final mx = cats.values.reduce((a, b) => a > b ? a : b);
                    final catColors = [AppColors.primary, AppColors.secondary, AppColors.accent, const Color(0xFFD97706), const Color(0xFFEF4444)];
                    return Column(children: cats.entries.toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final e = entry.value;
                      final color = catColors[idx % catColors.length];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Row(children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 8),
                              Text(e.key[0].toUpperCase() + e.key.substring(1), style: const TextStyle(color: AppColors.textMain, fontSize: 13, fontWeight: FontWeight.w600)),
                            ]),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text('${e.value} votes', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: mx > 0 ? e.value / mx : 0,
                              minHeight: 10,
                              backgroundColor: AppColors.surfaceAlt,
                              valueColor: AlwaysStoppedAnimation(color),
                            ),
                          ),
                        ]),
                      );
                    }).toList());
                  }()),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard(this.value, this.label, this.icon);
  final String value, label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

// ─── Performers Tab ───────────────────────────────────────────────────────────

class _PerformersTab extends ConsumerStatefulWidget {
  const _PerformersTab();
  @override
  ConsumerState<_PerformersTab> createState() => _PerformersTabState();
}

class _PerformersTabState extends ConsumerState<_PerformersTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _performers = [];
  bool _loading = true;
  String _filter = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Fetch performers and users separately to avoid join RLS issues
      final perfRes = await _supabase
          .from('performers')
          .select('id, talent_type, experience_level, bio, approval_status, avatar_url, created_at')
          .order('created_at', ascending: false);

      final perfList = (perfRes as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();

      if (perfList.isNotEmpty) {
        final ids = perfList.map((r) => r['id'] as String).toList();
        final userRes = await _supabase
            .from('users')
            .select('id, name, email')
            .inFilter('id', ids);
        final userMap = {
          for (final u in (userRes as List).cast<Map<String, dynamic>>())
            u['id'] as String: u
        };
        setState(() {
          _performers = perfList.map((p) {
            final u = userMap[p['id'] as String] ?? <String, dynamic>{};
            return {...p, ...u};
          }).toList();
          _loading = false;
        });
      } else {
        setState(() { _performers = []; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await _supabase.from('performers').update({'approval_status': status}).eq('id', id);

      // Send notification to the performer
      try {
        final isApproved = status == 'approved';
        await _supabase.from('notifications').insert({
          'user_id': id,
          'title': isApproved ? 'Profile Approved! ✅' : 'Profile Rejected ❌',
          'message': isApproved
              ? 'Your performer profile has been approved. You can now register for events!'
              : 'Your performer profile has been rejected. Please review the guidelines and try again.',
          'type': isApproved ? 'success' : 'error',
        });
      } catch (_) {} // non-fatal

      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_snack(
          status == 'approved' ? 'Performer approved ✅' : 'Performer rejected ❌',
          status == 'approved' ? AppColors.accent : AppColors.error,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Error: $e', AppColors.error));
    }
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm(context, 'Remove Performer', 'Permanently remove this performer?', 'Remove');
    if (!ok) return;
    await _supabase.from('performers').delete().eq('id', id);
    _load();
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _performers;
    if (_filter != 'all') list = list.where((p) => (p['approval_status'] ?? 'approved') == _filter).toList();
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) list = list.where((p) => (p['name'] ?? p['email'] ?? '').toString().toLowerCase().contains(q)).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Performers', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Approve or reject performer registrations', style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
          const SizedBox(height: 12),
          // Search
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search performers...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['all', 'pending', 'approved', 'rejected'].map((f) {
              final sel = _filter == f;
              final colors = {'all': AppColors.primary, 'pending': const Color(0xFFD97706), 'approved': AppColors.accent, 'rejected': AppColors.error};
              final c = colors[f]!;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? c.withValues(alpha: 0.12) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? c : AppColors.border),
                  ),
                  child: Text(f[0].toUpperCase() + f.substring(1), style: TextStyle(color: sel ? c : AppColors.textSub, fontWeight: sel ? FontWeight.w700 : FontWeight.normal, fontSize: 12)),
                ),
              );
            }).toList()),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _filtered.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: const Icon(Icons.mic_outlined, color: AppColors.textHint, size: 36)),
                    const SizedBox(height: 14),
                    const Text('No performers found', style: TextStyle(color: AppColors.textSub, fontSize: 15)),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load, color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final name = (p['name'] ?? p['email'] ?? 'Unknown') as String;
                        final status = (p['approval_status'] ?? 'approved') as String;
                        final statusColors = {'approved': AppColors.accent, 'rejected': AppColors.error, 'pending': const Color(0xFFD97706)};
                        final sc = statusColors[status] ?? AppColors.textSub;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _Card(p: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              _Av(name, photoUrl: p['avatar_url'] as String?),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
                                Text((p['email'] ?? '') as String, style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  _statusBadge(p['talent_type'] as String? ?? 'other', AppColors.surfaceAlt, AppColors.textSub),
                                  const SizedBox(width: 6),
                                  _statusBadge(status, sc.withValues(alpha: 0.12), sc),
                                ]),
                              ])),
                              GestureDetector(
                                onTap: () => _delete(p['id'] as String),
                                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18)),
                              ),
                            ]),
                            if (status != 'approved' || status != 'rejected') ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Row(children: [
                                if (status != 'approved') ...[
                                  Expanded(child: _actionBtn('✅ Approve', AppColors.accent, () => _setStatus(p['id'] as String, 'approved'))),
                                  if (status != 'rejected') const SizedBox(width: 10),
                                ],
                                if (status != 'rejected')
                                  Expanded(child: _actionBtn('❌ Reject', AppColors.error, () => _setStatus(p['id'] as String, 'rejected'))),
                              ]),
                            ],
                          ])),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}

// --- Users Tab ----------------------------------------------------------------

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();
  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _roleFilter = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase.from('users').select().order('created_at', ascending: false);
      setState(() { _users = (res as List).cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _changeRole(String id, String role) async {
    await _supabase.from('users').update({'role': role}).eq('id', id);
    _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Role updated to $role', AppColors.accent));
  }

  Future<void> _deleteUser(String id) async {
    final ok = await _confirm(context, 'Delete User', 'Remove this user from the system?', 'Delete');
    if (!ok) return;
    try {
      await _supabase.from('users').delete().eq('id', id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Error: $e', AppColors.error));
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _users;
    if (_roleFilter != 'all') list = list.where((u) => u['role'] == _roleFilter).toList();
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) list = list.where((u) => (u['name'] ?? u['email'] ?? '').toString().toLowerCase().contains(q)).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Users', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Manage all registered users', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Search users...', prefixIcon: Icon(Icons.search_rounded, size: 20), contentPadding: EdgeInsets.symmetric(vertical: 10)),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['all', 'student', 'performer', 'admin'].map((r) {
              final sel = _roleFilter == r;
              return GestureDetector(
                onTap: () => setState(() => _roleFilter = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: sel ? AppColors.primaryGradient : null,
                    color: sel ? null : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? Colors.transparent : AppColors.border),
                    boxShadow: sel ? AppColors.primaryShadow : null,
                  ),
                  child: Text(r[0].toUpperCase() + r.substring(1), style: TextStyle(color: sel ? Colors.white : AppColors.textSub, fontWeight: sel ? FontWeight.w700 : FontWeight.normal, fontSize: 12)),
                ),
              );
            }).toList()),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _filtered.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: const Icon(Icons.people_outline_rounded, color: AppColors.textHint, size: 36)),
                    const SizedBox(height: 14),
                    const Text('No users found', style: TextStyle(color: AppColors.textSub, fontSize: 15)),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load, color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final u = _filtered[i];
                        final name = (u['name'] ?? u['email'] ?? 'Unknown') as String;
                        final role = (u['role'] ?? 'student') as String;
                        final roleColors = {'admin': AppColors.primary, 'performer': const Color(0xFFD97706), 'student': AppColors.accent};
                        final rc = roleColors[role] ?? AppColors.textSub;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _Card(p: const EdgeInsets.all(14), child: Row(children: [
                            _Av(name),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text((u['email'] ?? '') as String, style: const TextStyle(color: AppColors.textSub, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              _statusBadge(role, rc.withValues(alpha: 0.12), rc),
                            ])),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              color: AppColors.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
                              elevation: 4,
                              icon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Icon(Icons.more_vert_rounded, color: AppColors.textSub, size: 18)),
                              onSelected: (val) { if (val == 'delete') { _deleteUser(u['id'] as String); } else { _changeRole(u['id'] as String, val); } },
                              itemBuilder: (_) => [
                                if (role != 'student') PopupMenuItem(value: 'student', child: _menuItem(Icons.school_rounded, 'Make Student', AppColors.accent)),
                                if (role != 'performer') PopupMenuItem(value: 'performer', child: _menuItem(Icons.mic_rounded, 'Make Performer', const Color(0xFFD97706))),
                                if (role != 'admin') PopupMenuItem(value: 'admin', child: _menuItem(Icons.shield_rounded, 'Make Admin', AppColors.primary)),
                                const PopupMenuDivider(),
                                PopupMenuItem(value: 'delete', child: _menuItem(Icons.delete_rounded, 'Delete User', AppColors.error)),
                              ],
                            ),
                          ])),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }

  Widget _menuItem(IconData icon, String label, Color color) => Row(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
  ]);
}

// --- Events Tab ---------------------------------------------------------------

class _EventsTab extends ConsumerStatefulWidget {
  const _EventsTab({required this.titleCtrl, required this.locationCtrl});
  final TextEditingController titleCtrl, locationCtrl;
  @override
  ConsumerState<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<_EventsTab> {
  final _supabase = Supabase.instance.client;
  bool _creating = false;
  List<Map<String, dynamic>> _events = [];
  bool _loadingEvents = true;

  // Date/time state for create form
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime? _endDate;
  TimeOfDay? _endTime;
  DateTime? _votingDeadlineDate;
  TimeOfDay? _votingDeadlineTime;
  DateTime? _expiresAtDate;
  TimeOfDay? _expiresAtTime;
  int _votesPerUser = 1; // vote limit per student

  @override
  void initState() { super.initState(); _loadEvents(); }

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final res = await _supabase.from('events').select().order('event_date', ascending: true);
      if (mounted) setState(() { _events = (res as List).cast<Map<String, dynamic>>(); _loadingEvents = false; });
    } catch (_) { if (mounted) setState(() => _loadingEvents = false); }
  }

  Future<void> _pickStartDate() async {
    final d = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 2)));
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _pickStartTime() async {
    final t = await showTimePicker(context: context, initialTime: _startTime);
    if (t != null) setState(() => _startTime = t);
  }

  Future<void> _pickEndDate() async {
    final d = await showDatePicker(context: context, initialDate: _endDate ?? _startDate, firstDate: _startDate, lastDate: DateTime.now().add(const Duration(days: 365 * 2)));
    if (d != null) setState(() => _endDate = d);
  }

  Future<void> _pickEndTime() async {
    final t = await showTimePicker(context: context, initialTime: _endTime ?? const TimeOfDay(hour: 18, minute: 0));
    if (t != null) setState(() => _endTime = t);
  }

  Future<void> _pickVotingDeadlineDate() async {
    final d = await showDatePicker(context: context, initialDate: _votingDeadlineDate ?? _startDate, firstDate: _startDate, lastDate: DateTime.now().add(const Duration(days: 365 * 2)));
    if (d != null) setState(() => _votingDeadlineDate = d);
  }

  Future<void> _pickVotingDeadlineTime() async {
    final t = await showTimePicker(context: context, initialTime: _votingDeadlineTime ?? const TimeOfDay(hour: 20, minute: 0));
    if (t != null) setState(() => _votingDeadlineTime = t);
  }

  Future<void> _pickExpiresAtDate() async {
    final d = await showDatePicker(context: context, initialDate: _expiresAtDate ?? _startDate, firstDate: _startDate, lastDate: DateTime.now().add(const Duration(days: 365 * 2)));
    if (d != null) setState(() => _expiresAtDate = d);
  }

  Future<void> _pickExpiresAtTime() async {
    final t = await showTimePicker(context: context, initialTime: _expiresAtTime ?? const TimeOfDay(hour: 23, minute: 59));
    if (t != null) setState(() => _expiresAtTime = t);
  }

  DateTime _combine(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:${t.minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _create() async {
    if (widget.titleCtrl.text.trim().isEmpty) return;
    setState(() => _creating = true);
    try {
      final realUserId = _supabase.auth.currentUser?.id;
      final startDt = _combine(_startDate, _startTime);
      final endDt = _endDate != null && _endTime != null ? _combine(_endDate!, _endTime!) : null;
      final votingDeadlineDt = _votingDeadlineDate != null && _votingDeadlineTime != null
          ? _combine(_votingDeadlineDate!, _votingDeadlineTime!)
          : null;
      final expiresAtDt = _expiresAtDate != null && _expiresAtTime != null
          ? _combine(_expiresAtDate!, _expiresAtTime!)
          : null;
      final payload = <String, dynamic>{
        'title': widget.titleCtrl.text.trim(),
        'location': widget.locationCtrl.text.trim().isEmpty ? null : widget.locationCtrl.text.trim(),
        'event_date': startDt.toIso8601String(),
        if (endDt != null) 'end_date': endDt.toIso8601String(),
        if (votingDeadlineDt != null) 'voting_deadline': votingDeadlineDt.toIso8601String(),
        if (expiresAtDt != null) 'expires_at': expiresAtDt.toIso8601String(),
        'status': 'upcoming',
        'votes_per_user': _votesPerUser,
      };
      if (realUserId != null) payload['created_by'] = realUserId;
      await _supabase.from('events').insert(payload);
      widget.titleCtrl.clear(); widget.locationCtrl.clear();
      setState(() {
        _endDate = null; _endTime = null;
        _votingDeadlineDate = null; _votingDeadlineTime = null;
        _expiresAtDate = null; _expiresAtTime = null;
        _votesPerUser = 1;
      });
      ref.invalidate(eventsProvider);
      await _loadEvents();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Event created ✅', AppColors.accent));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Error: $e', AppColors.error));
    } finally { if (mounted) setState(() => _creating = false); }
  }

  Future<void> _setStatus(String id, String status) async {
    await _supabase.from('events').update({'status': status}).eq('id', id);
    ref.invalidate(eventsProvider);
    await _loadEvents();
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm(context, 'Delete Event', 'Delete this event and all its votes?', 'Delete');
    if (!ok) return;
    await _supabase.from('events').delete().eq('id', id);
    ref.invalidate(eventsProvider);
    await _loadEvents();
  }

  Future<void> _showRegistrations(String eventId, String eventTitle) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegistrationsSheet(eventId: eventId, eventTitle: eventTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Events', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
          GestureDetector(onTap: _loadEvents, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20))),
        ]),
        const SizedBox(height: 4),
        const Text('Create and manage talent show events', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
        const SizedBox(height: 20),
        // Create form
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 10),
            const Text('Create New Event', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: widget.titleCtrl, decoration: const InputDecoration(hintText: 'Event title *', prefixIcon: Icon(Icons.event_rounded, size: 20))),
          const SizedBox(height: 10),
          TextField(controller: widget.locationCtrl, decoration: const InputDecoration(hintText: 'Location (optional)', prefixIcon: Icon(Icons.location_on_rounded, size: 20))),
          const SizedBox(height: 14),
          // Start date & time
          const Text('Start', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _DateTimeChip(
              icon: Icons.calendar_today_rounded,
              label: _fmtDate(_startDate),
              onTap: _pickStartDate,
            )),
            const SizedBox(width: 8),
            Expanded(child: _DateTimeChip(
              icon: Icons.access_time_rounded,
              label: _fmtTime(_startTime),
              onTap: _pickStartTime,
            )),
          ]),
          const SizedBox(height: 12),
          // End date & time (optional)
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('End (optional)', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
            if (_endDate != null)
              GestureDetector(
                onTap: () => setState(() { _endDate = null; _endTime = null; }),
                child: const Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _DateTimeChip(
              icon: Icons.calendar_today_rounded,
              label: _endDate != null ? _fmtDate(_endDate!) : 'End date',
              onTap: _pickEndDate,
              muted: _endDate == null,
            )),
            const SizedBox(width: 8),
            Expanded(child: _DateTimeChip(
              icon: Icons.access_time_rounded,
              label: _endTime != null ? _fmtTime(_endTime!) : 'End time',
              onTap: _pickEndTime,
              muted: _endTime == null,
            )),
          ]),
          const SizedBox(height: 14),
          // Voting deadline (optional)
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Voting deadline (optional)', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
            if (_votingDeadlineDate != null)
              GestureDetector(
                onTap: () => setState(() { _votingDeadlineDate = null; _votingDeadlineTime = null; }),
                child: const Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _DateTimeChip(
              icon: Icons.how_to_vote_rounded,
              label: _votingDeadlineDate != null ? _fmtDate(_votingDeadlineDate!) : 'Deadline date',
              onTap: _pickVotingDeadlineDate,
              muted: _votingDeadlineDate == null,
            )),
            const SizedBox(width: 8),
            Expanded(child: _DateTimeChip(
              icon: Icons.access_time_rounded,
              label: _votingDeadlineTime != null ? _fmtTime(_votingDeadlineTime!) : 'Deadline time',
              onTap: _pickVotingDeadlineTime,
              muted: _votingDeadlineTime == null,
            )),
          ]),
          const SizedBox(height: 12),
          // Event expire date (optional)
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Event expires at (optional)', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
            if (_expiresAtDate != null)
              GestureDetector(
                onTap: () => setState(() { _expiresAtDate = null; _expiresAtTime = null; }),
                child: const Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _DateTimeChip(
              icon: Icons.event_busy_rounded,
              label: _expiresAtDate != null ? _fmtDate(_expiresAtDate!) : 'Expire date',
              onTap: _pickExpiresAtDate,
              muted: _expiresAtDate == null,
            )),
            const SizedBox(width: 8),
            Expanded(child: _DateTimeChip(
              icon: Icons.access_time_rounded,
              label: _expiresAtTime != null ? _fmtTime(_expiresAtTime!) : 'Expire time',
              onTap: _pickExpiresAtTime,
              muted: _expiresAtTime == null,
            )),
          ]),
          const SizedBox(height: 14),
          // Vote limit per student
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [            const Text('Votes per student', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () { if (_votesPerUser > 1) setState(() => _votesPerUser--); },
                  child: Container(padding: const EdgeInsets.all(6), child: const Icon(Icons.remove_rounded, size: 16, color: AppColors.textSub)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8)),
                  child: Text('$_votesPerUser', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                GestureDetector(
                  onTap: () { if (_votesPerUser < 10) setState(() => _votesPerUser++); },
                  child: Container(padding: const EdgeInsets.all(6), child: const Icon(Icons.add_rounded, size: 16, color: AppColors.textSub)),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Each student can vote $_votesPerUser time${_votesPerUser == 1 ? '' : 's'} per event', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
          const SizedBox(height: 14),
          SizedBox(height: 50, width: double.infinity, child: ElevatedButton(
            onPressed: _creating ? null : _create,
            child: _creating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Event'),
          )),
        ])),
        const SizedBox(height: 20),
        const Text('All Events', style: TextStyle(color: AppColors.textMain, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (_loadingEvents)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
        else if (_events.isEmpty)
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: const Center(child: Text('No events yet', style: TextStyle(color: AppColors.textSub))))
        else
          ..._events.map((evMap) {
            final ev = Event.fromJson(evMap);
            final statusColors = {'upcoming': const Color(0xFFD97706), 'active': AppColors.accent, 'completed': AppColors.primary, 'cancelled': AppColors.error};
                  final sc = statusColors[ev.status.value] ?? AppColors.textSub;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Card(p: const EdgeInsets.all(14), child: Row(children: [
                      Container(width: 46, height: 46, decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.event_rounded, color: Colors.white, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ev.title, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(ev.location ?? 'No location', style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 12),
                          const SizedBox(width: 4),
                          Expanded(child: Text(ev.formattedStart, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        ]),
                        if (ev.formattedEnd != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.schedule_rounded, color: AppColors.textHint, size: 12),
                            const SizedBox(width: 4),
                            Expanded(child: Text('End: ${ev.formattedEnd!}', style: const TextStyle(color: AppColors.textHint, fontSize: 11), overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                        const SizedBox(height: 4),
                        Row(children: [
                          _statusBadge(ev.status.value, sc.withValues(alpha: 0.12), sc),
                          const SizedBox(width: 6),
                          _statusBadge('${ev.votesPerUser} vote${ev.votesPerUser == 1 ? '' : 's'}/student', const Color(0xFFEEF2FF), AppColors.primary),
                        ]),
                        if (ev.votingDeadline != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.how_to_vote_rounded, color: Color(0xFFD97706), size: 12),
                            const SizedBox(width: 4),
                            Expanded(child: Text('Voting closes: ${ev.formattedVotingDeadline!}', style: const TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                        if (ev.expiresAt != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.event_busy_rounded, color: AppColors.error, size: 12),
                            const SizedBox(width: 4),
                            Expanded(child: Text('Expires: ${ev.formattedExpiresAt!}', style: const TextStyle(color: AppColors.error, fontSize: 11), overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                      ])),
                      PopupMenuButton<String>(
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
                        elevation: 4,
                        icon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Icon(Icons.more_vert_rounded, color: AppColors.textSub, size: 18)),
                        onSelected: (val) {
                          if (val == 'delete') {
                            _delete(ev.id);
                          } else if (val == 'registrations') {
                            _showRegistrations(ev.id, ev.title);
                          } else {
                            _setStatus(ev.id, val);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'registrations', child: Row(children: [Icon(Icons.how_to_reg_rounded, color: AppColors.primary, size: 18), const SizedBox(width: 8), Text('Registrations', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))])),
                          const PopupMenuDivider(),
                          if (ev.status.value != 'active') PopupMenuItem(value: 'active', child: Row(children: [Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 18), const SizedBox(width: 8), Text('Activate', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600))])),
                          if (ev.status.value == 'active') PopupMenuItem(value: 'upcoming', child: Row(children: [const Icon(Icons.pause_rounded, color: Color(0xFFD97706), size: 18), const SizedBox(width: 8), const Text('Deactivate', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w600))])),
                          if (ev.status.value != 'completed') PopupMenuItem(value: 'completed', child: Row(children: [Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18), const SizedBox(width: 8), Text('Complete', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))])),
                          const PopupMenuDivider(),
                          PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, color: AppColors.error, size: 18), const SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600))])),
                        ],
                      ),
                    ])),
                  );
                }),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Registrations Sheet ─────────────────────────────────────────────────────

class _RegistrationsSheet extends StatefulWidget {
  const _RegistrationsSheet({required this.eventId, required this.eventTitle});
  final String eventId, eventTitle;
  @override
  State<_RegistrationsSheet> createState() => _RegistrationsSheetState();
}

class _RegistrationsSheetState extends State<_RegistrationsSheet> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _regs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Fetch registrations
      final regs = await _supabase
          .from('event_registrations')
          .select('id, performer_id, performance_title, performance_description, status, submission_date')
          .eq('event_id', widget.eventId)
          .order('submission_date', ascending: false);
      final regList = (regs as List).cast<Map<String, dynamic>>();

      if (regList.isEmpty) {
        if (mounted) setState(() { _regs = []; _loading = false; });
        return;
      }

      // Fetch performer names
      final ids = regList.map((r) => r['performer_id'] as String).toList();
      final users = await _supabase.from('users').select('id, name, email').inFilter('id', ids);
      final userMap = { for (final u in (users as List).cast<Map<String, dynamic>>()) u['id'] as String: u };

      if (mounted) setState(() {
        _regs = regList.map((r) {
          final u = userMap[r['performer_id'] as String] ?? {};
          return {...r, 'name': u['name'] ?? u['email'] ?? 'Unknown', 'email': u['email'] ?? ''};
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setRegStatus(String regId, String performerId, String status) async {
    try {
      await _supabase.from('event_registrations').update({'status': status}).eq('id', regId);

      // Notify performer
      await _supabase.from('notifications').insert({
        'user_id': performerId,
        'title': status == 'approved' ? 'Registration Approved! ✅' : 'Registration Rejected ❌',
        'message': status == 'approved'
            ? 'Your registration for "${widget.eventTitle}" has been approved. Get ready to perform!'
            : 'Your registration for "${widget.eventTitle}" was not approved this time.',
        'type': status == 'approved' ? 'success' : 'error',
      });

      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'approved' ? 'Registration approved ✅' : 'Registration rejected ❌'),
        backgroundColor: status == 'approved' ? AppColors.accent : AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Handle
        Center(child: Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Registrations', style: TextStyle(color: AppColors.textMain, fontSize: 18, fontWeight: FontWeight.w800)),
              Text(widget.eventTitle, style: const TextStyle(color: AppColors.textSub, fontSize: 12), overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(onTap: _load, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18))),
            const SizedBox(width: 8),
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Icon(Icons.close_rounded, color: AppColors.textSub, size: 18))),
          ]),
        ),
        const Divider(height: 1),
        // List
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _regs.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: const Icon(Icons.inbox_rounded, color: AppColors.textHint, size: 32)),
                  const SizedBox(height: 12),
                  const Text('No registrations yet', style: TextStyle(color: AppColors.textSub, fontSize: 15)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _regs.length,
                  itemBuilder: (_, i) {
                    final r = _regs[i];
                    final status = r['status'] as String? ?? 'pending';
                    final statusColors = {'approved': AppColors.accent, 'rejected': AppColors.error, 'pending': const Color(0xFFD97706)};
                    final sc = statusColors[status] ?? AppColors.textSub;
                    final name = r['name'] as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          _Av(name),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
                            Text(r['performance_title'] as String? ?? '', style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                          ])),
                          _statusBadge(status, sc.withValues(alpha: 0.12), sc),
                        ]),
                        if ((r['performance_description'] as String?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(r['performance_description'] as String, style: const TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(children: [
                          if (status != 'approved') ...[
                            Expanded(child: _actionBtn('✅ Approve', AppColors.accent, () => _setRegStatus(r['id'] as String, r['performer_id'] as String, 'approved'))),
                            const SizedBox(width: 10),
                          ],
                          if (status != 'rejected')
                            Expanded(child: _actionBtn('❌ Reject', AppColors.error, () => _setRegStatus(r['id'] as String, r['performer_id'] as String, 'rejected'))),
                          if (status == 'approved' && status != 'rejected')
                            Expanded(child: _actionBtn('↩ Pending', const Color(0xFFD97706), () => _setRegStatus(r['id'] as String, r['performer_id'] as String, 'pending'))),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─── DateTimeChip widget ─────────────────────────────────────────────────────

class _DateTimeChip extends StatelessWidget {
  const _DateTimeChip({required this.icon, required this.label, required this.onTap, this.muted = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: muted ? AppColors.surfaceAlt : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: muted ? AppColors.border : AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: muted ? AppColors.textHint : AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: TextStyle(color: muted ? AppColors.textHint : AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

// --- Confirm Dialog helper ----------------------------------------------------

Future<bool> _confirm(BuildContext context, String title, String message, String confirmLabel) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 17)),
      content: Text(message, style: const TextStyle(color: AppColors.textSub, fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _AdminsTab extends ConsumerStatefulWidget {
  const _AdminsTab({required this.currentUser});
  final dynamic currentUser;
  @override
  ConsumerState<_AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends ConsumerState<_AdminsTab> {
  final _supabase = Supabase.instance.client;
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true, _submitting = false;
  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadAdmins(); }
  @override
  void dispose() { _emailCtrl.dispose(); _nameCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _loadAdmins() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase.from('users').select().eq('role', 'admin').order('created_at', ascending: false);
      setState(() { _admins = (res as List).cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _addAdmin() async {
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || name.isEmpty || pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(_snack('Fill all fields. Password must be 6+ characters.', AppColors.warning));
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _supabase.auth.signUp(email: email.toLowerCase(), password: pass, data: {'name': name, 'role': 'admin'});
      if (res.user != null) {
        await _supabase.from('users').upsert({'id': res.user!.id, 'email': email.toLowerCase(), 'name': name, 'role': 'admin', 'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()});
        _emailCtrl.clear(); _nameCtrl.clear(); _passCtrl.clear();
        _loadAdmins();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Admin "$name" created ?', AppColors.accent));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack(e.toString().replaceFirst('Exception: ', ''), AppColors.error));
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  Future<void> _promoteExisting() async {
    final emailCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Promote to Admin', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Enter the email of an existing user:', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
        const SizedBox(height: 12),
        TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'user@email.com', prefixIcon: Icon(Icons.alternate_email_rounded, size: 20))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Promote')),
      ],
    ));
    if (ok != true || emailCtrl.text.trim().isEmpty) return;
    try {
      await _supabase.from('users').update({'role': 'admin'}).eq('email', emailCtrl.text.trim().toLowerCase());
      _loadAdmins();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('User promoted to admin ?', AppColors.accent));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Error: $e', AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
      children: [
        const Text('Admins', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Manage admin accounts', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
        const SizedBox(height: 20),
        // Create admin form
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('? Create New Admin', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Creates a new account with admin role', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded, size: 20))),
          const SizedBox(height: 10),
          TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email address', prefixIcon: Icon(Icons.alternate_email_rounded, size: 20))),
          const SizedBox(height: 10),
          TextField(
            controller: _passCtrl, obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'Password (min 6 chars)',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: GestureDetector(onTap: () => setState(() => _obscure = !_obscure), child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppColors.textHint)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50, width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _addAdmin,
              icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.shield_rounded),
              label: Text(_submitting ? 'Creating...' : 'Create Admin'),
            ),
          ),
        ])),
        const SizedBox(height: 12),
        // Promote existing
        GestureDetector(
          onTap: _promoteExisting,
          child: _Card(p: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.upgrade_rounded, color: AppColors.primary, size: 22)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Promote Existing User', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
              Text('Give admin role to an existing account', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
          ])),
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Current Admins', style: TextStyle(color: AppColors.textMain, fontSize: 17, fontWeight: FontWeight.w800)),
          GestureDetector(onTap: _loadAdmins, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Icon(Icons.refresh_rounded, color: AppColors.textSub, size: 18))),
        ]),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else if (_admins.isEmpty)
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: const Center(child: Text('No admins found', style: TextStyle(color: AppColors.textSub))))
        else
          ..._admins.map((a) {
            final name = (a['name'] ?? a['email'] ?? 'Admin') as String;
            final isMe = a['id'] == widget.currentUser?.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Card(p: const EdgeInsets.all(14), child: Row(children: [
                _Av(name),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(name, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
                    if (isMe) ...[const SizedBox(width: 6), _statusBadge('You', const Color(0xFFEEF2FF), AppColors.primary)],
                  ]),
                  Text((a['email'] ?? '') as String, style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
                ])),
                if (!isMe)
                  GestureDetector(
                    onTap: () async {
                      final ok = await _confirm(context, 'Remove Admin', 'Demote this admin to student role?', 'Demote');
                      if (!ok) return;
                      await _supabase.from('users').update({'role': 'student'}).eq('id', a['id'] as String);
                      _loadAdmins();
                    },
                    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_remove_rounded, color: AppColors.error, size: 18)),
                  ),
              ])),
            );
          }),
      ],
    );
  }
}






