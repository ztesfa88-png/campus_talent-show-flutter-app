import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/app_data_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/event.dart';

// -----------------------------------------------------------------------------
// PERFORMER APP SHELL
// -----------------------------------------------------------------------------

class PerformerAppShell extends ConsumerStatefulWidget {
  const PerformerAppShell({super.key});
  @override
  ConsumerState<PerformerAppShell> createState() => _PerformerAppShellState();
}

class _PerformerAppShellState extends ConsumerState<PerformerAppShell> {
  int _tab = 0;
  static const _tabs = [
    (Icons.dashboard_rounded,        Icons.dashboard_outlined,        'Dashboard'),
    (Icons.notifications_rounded,    Icons.notifications_outlined,    'Alerts'),
    (Icons.perm_media_rounded,       Icons.perm_media_outlined,       'Portfolio'),
    (Icons.event_rounded,            Icons.event_outlined,            'Events'),
    (Icons.emoji_events_rounded,     Icons.emoji_events_outlined,     'Results'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final bodies = [
      _Dashboard(user: user),
      _Notifications(user: user),
      _Portfolio(user: user),
      _Events(user: user),
      _Results(user: user),
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
        child: SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(_tabs.length, (i) {
            final t = _tabs[i]; final sel = _tab == i;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: sel ? const Color(0xFFEEF2FF) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(sel ? t.$1 : t.$2, color: sel ? AppColors.primary : AppColors.textHint, size: 22),
                  const SizedBox(height: 2),
                  Text(t.$3, style: TextStyle(color: sel ? AppColors.primary : AppColors.textHint, fontSize: 9, fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                ]),
              ),
            );
          })),
        )),
      ),
    );
  }
}

// --- Shared helpers -----------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child; final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
    child: child,
  );
}

SnackBar _snack(String msg, Color color) => SnackBar(
  content: Text(msg), backgroundColor: color,
  behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

// ─── Dashboard ────────────────────────────────────────────────────────────────

class _Dashboard extends ConsumerStatefulWidget {
  const _Dashboard({required this.user});
  final dynamic user;
  @override
  ConsumerState<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<_Dashboard> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _stats;

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    try {
      final userId = widget.user?.id;
      if (userId == null) return;
      final votes = await _supabase.from('votes').select('score').eq('performer_id', userId);
      final comments = await _supabase.from('feedback').select('rating').eq('performer_id', userId);
      final voteList = (votes as List).cast<Map<String, dynamic>>();
      final commentList = (comments as List).cast<Map<String, dynamic>>();
      final avgScore = voteList.isEmpty ? 0.0 : voteList.map((v) => v['score'] as int).reduce((a, b) => a + b) / voteList.length;
      final avgRating = commentList.isEmpty ? 0.0 : commentList.where((c) => c['rating'] != null).map((c) => c['rating'] as int).fold(0, (a, b) => a + b) / (commentList.where((c) => c['rating'] != null).length.clamp(1, 999));
      if (mounted) setState(() => _stats = {'votes': voteList.length, 'avgScore': avgScore, 'comments': commentList.length, 'avgRating': avgRating});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);
    final name = widget.user?.name ?? 'Performer';
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async { _loadStats(); ref.invalidate(eventsProvider); },
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.primaryShadow),
            child: Row(children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)),
                child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Welcome back,', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Text('🎤 Performer', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
              ])),
              GestureDetector(
                onTap: () async { await ref.read(authStateProvider.notifier).signOut(); if (context.mounted) context.go('/login'); },
                child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20)),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          // Stats
          Row(children: [
            _StatCard('${_stats?['votes'] ?? 0}', 'Votes', Icons.how_to_vote_rounded, AppColors.primary),
            const SizedBox(width: 12),
            _StatCard((_stats?['avgScore'] as double? ?? 0.0).toStringAsFixed(1), 'Avg Score', Icons.star_rounded, const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _StatCard('${_stats?['comments'] ?? 0}', 'Reviews', Icons.comment_rounded, AppColors.accent),
            const SizedBox(width: 12),
            _StatCard((_stats?['avgRating'] as double? ?? 0.0).toStringAsFixed(1), 'Avg Rating', Icons.thumb_up_rounded, AppColors.secondary),
          ]),
          const SizedBox(height: 20),
          // Profile completion
          _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Profile Completion', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)), child: const Text('68%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
            ]),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: const LinearProgressIndicator(value: 0.68, minHeight: 10, backgroundColor: Color(0xFFEEF2FF), valueColor: AlwaysStoppedAnimation(AppColors.primary))),
            const SizedBox(height: 8),
            const Text('Add profile photo, bio and social links to reach 100%', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
          ])),
          const SizedBox(height: 20),
          const Text('Upcoming Events', style: TextStyle(color: AppColors.textMain, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          events.when(
            data: (items) => items.isEmpty
                ? _Card(padding: const EdgeInsets.all(20), child: const Center(child: Text('No upcoming events', style: TextStyle(color: AppColors.textSub))))
                : Column(children: items.take(3).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Card(padding: const EdgeInsets.all(14), child: Row(children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.event_rounded, color: Colors.white, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.title, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(e.location ?? 'TBD', style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 11),
                          const SizedBox(width: 3),
                          Expanded(child: Text(e.formattedStart, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        ]),
                        if (e.registrationDeadline != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(Icons.how_to_reg_rounded, color: e.isRegistrationOpen ? const Color(0xFFD97706) : AppColors.error, size: 11),
                            const SizedBox(width: 3),
                            Expanded(child: Text(
                              e.isRegistrationOpen ? 'Register by: ${e.formattedRegistrationDeadline!}' : 'Registration closed',
                              style: TextStyle(color: e.isRegistrationOpen ? const Color(0xFFD97706) : AppColors.error, fontSize: 10, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            )),
                          ]),
                        ],
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: e.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)), child: Text(e.status.value, style: TextStyle(color: e.isActive ? AppColors.accent : const Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.w600))),
                    ])),
                  )).toList()),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.value, this.label, this.icon, this.color);
  final String value, label; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
      ]),
    ]),
  ));
}

// ─── Portfolio (with profile picture upload) ──────────────────────────────────

class _Portfolio extends ConsumerStatefulWidget {
  const _Portfolio({required this.user});
  final dynamic user;
  @override
  ConsumerState<_Portfolio> createState() => _PortfolioState();
}

class _PortfolioState extends ConsumerState<_Portfolio> {
  final _supabase = Supabase.instance.client;
  final _bioCtrl = TextEditingController();
  final _talentCtrl = TextEditingController();
  String? _avatarUrl;
  bool _uploading = false;
  bool _savingBio = false;
  bool _loaded = false;
  String _selectedTalent = 'other';
  String _selectedLevel = 'beginner';

  static const _talents = ['music', 'dance', 'comedy', 'drama', 'magic', 'other'];
  static const _levels = ['beginner', 'intermediate', 'advanced'];

  @override
  void initState() { super.initState(); _loadProfile(); }
  @override
  void dispose() { _bioCtrl.dispose(); _talentCtrl.dispose(); super.dispose(); }

  Future<void> _loadProfile() async {
    try {
      final userId = widget.user?.id;
      if (userId == null) return;
      // Select without avatar_url first for compatibility, then try with it
      Map<String, dynamic>? res;
      try {
        res = await _supabase.from('performers').select('bio, talent_type, experience_level, avatar_url').eq('id', userId).maybeSingle();
      } catch (_) {
        // avatar_url column may not exist yet � fallback without it
        res = await _supabase.from('performers').select('bio, talent_type, experience_level').eq('id', userId).maybeSingle();
      }
      final data = res;
      if (data != null && mounted) {
        setState(() {
          _bioCtrl.text = data['bio'] as String? ?? '';
          _selectedTalent = data['talent_type'] as String? ?? 'other';
          _selectedLevel = data['experience_level'] as String? ?? 'beginner';
          _avatarUrl = data['avatar_url'] as String?;
          _loaded = true;
        });
      } else if (mounted) {
        setState(() => _loaded = true);
      }
    } catch (_) { if (mounted) setState(() => _loaded = true); }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final userId = widget.user?.id;
      if (userId == null) return;
      final bytes = await picked.readAsBytes();
      final fileName = 'avatars/$userId.jpg';

      await _supabase.storage.from('avatars').uploadBinary(
        fileName, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      final url = _supabase.storage.from('avatars').getPublicUrl(fileName);
      try {
        await _supabase.from('performers').update({'avatar_url': url}).eq('id', userId);
      } catch (_) {
        // avatar_url column missing � run: ALTER TABLE public.performers ADD COLUMN IF NOT EXISTS avatar_url TEXT;
        throw Exception('avatar_url column missing. Run the SQL migration in Supabase.');
      }

      if (mounted) {
        setState(() { _avatarUrl = url; _uploading = false; });
        ScaffoldMessenger.of(context).showSnackBar(_snack('Profile photo updated! ✅', AppColors.accent));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(_snack('Upload failed: $e', AppColors.error));
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _savingBio = true);
    try {
      final userId = widget.user?.id;
      if (userId == null) return;
      await _supabase.from('performers').update({
        'bio': _bioCtrl.text.trim(),
        'talent_type': _selectedTalent,
        'experience_level': _selectedLevel,
      }).eq('id', userId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Profile saved! ✅', AppColors.accent));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Error: $e', AppColors.error));
    } finally { if (mounted) setState(() => _savingBio = false); }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user?.name ?? 'Performer';
    if (!_loaded) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return ListView(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
      children: [
        const Text('Portfolio', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Manage your profile and media', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
        const SizedBox(height: 20),

        // ── Profile Photo ──────────────────────────────────────────────────
        _Card(child: Column(children: [
          const Text('Profile Photo', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 16),
          Center(
            child: Stack(children: [
              // Avatar
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: _avatarUrl == null ? AppColors.heroGradient : null,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: AppColors.primaryShadow,
                ),
                child: _avatarUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(_avatarUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)))),
                      )
                    : Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900))),
              ),
              // Upload button overlay
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _uploading ? null : _pickAndUploadPhoto,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                      boxShadow: AppColors.primaryShadow,
                    ),
                    child: _uploading
                        ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Text(
            _uploading ? 'Uploading...' : 'Tap the camera icon to change photo',
            style: const TextStyle(color: AppColors.textSub, fontSize: 12),
          ),
        ])),
        const SizedBox(height: 16),

        // ── Bio & Talent ───────────────────────────────────────────────────
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Profile Info', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 14),
          // Talent type
          const Text('Talent Type', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: _talents.map((t) {
            final sel = _selectedTalent == t;
            return GestureDetector(
              onTap: () => setState(() => _selectedTalent = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: sel ? AppColors.primaryGradient : null,
                  color: sel ? null : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? Colors.transparent : AppColors.border),
                ),
                child: Text(t[0].toUpperCase() + t.substring(1), style: TextStyle(color: sel ? Colors.white : AppColors.textSub, fontWeight: sel ? FontWeight.w700 : FontWeight.normal, fontSize: 12)),
              ),
            );
          }).toList()),
          const SizedBox(height: 14),
          // Experience level
          const Text('Experience Level', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: _levels.map((l) {
            final sel = _selectedLevel == l;
            return Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedLevel = l),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: sel ? AppColors.primaryGradient : null,
                    color: sel ? null : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? Colors.transparent : AppColors.border),
                  ),
                  child: Center(child: Text(l[0].toUpperCase() + l.substring(1), style: TextStyle(color: sel ? Colors.white : AppColors.textSub, fontWeight: sel ? FontWeight.w700 : FontWeight.normal, fontSize: 11))),
                ),
              ),
            ));
          }).toList()),
          const SizedBox(height: 14),
          // Bio
          const Text('Bio', style: TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _bioCtrl, maxLines: 4,
            decoration: const InputDecoration(hintText: 'Tell your audience about yourself...'),
          ),
          const SizedBox(height: 14),
          SizedBox(height: 50, width: double.infinity, child: ElevatedButton.icon(
            onPressed: _savingBio ? null : _saveProfile,
            icon: _savingBio ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
            label: Text(_savingBio ? 'Saving...' : 'Save Profile'),
          )),
        ])),
      ],
    );
  }
}

// ─── Events (with registration) ───────────────────────────────────────────────

class _Events extends ConsumerStatefulWidget {
  const _Events({required this.user});
  final dynamic user;
  @override
  ConsumerState<_Events> createState() => _EventsState();
}

class _EventsState extends ConsumerState<_Events> {
  final _supabase = Supabase.instance.client;
  Set<String> _registeredEventIds = {};
  bool _loadingRegs = true;

  @override
  void initState() { super.initState(); _loadRegistrations(); }

  Future<void> _loadRegistrations() async {
    try {
      final userId = widget.user?.id;
      if (userId == null) return;
      final res = await _supabase.from('event_registrations').select('event_id').eq('performer_id', userId);
      if (mounted) {
        setState(() {
        _registeredEventIds = (res as List).map((r) => r['event_id'] as String).toSet();
        _loadingRegs = false;
      });
      }
    } catch (_) { if (mounted) setState(() => _loadingRegs = false); }
  }

  Future<void> _register(Event event) async {
    final userId = widget.user?.id;
    if (userId == null) return;

    // Show registration dialog
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Register for ${event.title}', style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: 'Performance title *', prefixIcon: Icon(Icons.mic_rounded, size: 20))),
          const SizedBox(height: 10),
          TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Description (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Register'),
          ),
        ],
      ),
    );

    if (ok != true || titleCtrl.text.trim().isEmpty) return;

    try {
      await _supabase.from('event_registrations').insert({
        'event_id': event.id,
        'performer_id': userId,
        'performance_title': titleCtrl.text.trim(),
        'performance_description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        'status': 'pending',
      });
      setState(() => _registeredEventIds.add(event.id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Registered for ${event.title}! ✅', AppColors.accent));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Error: ${e.toString().replaceFirst('Exception: ', '')}', AppColors.error));
    }
  }

  Future<void> _unregister(Event event) async {
    final userId = widget.user?.id;
    if (userId == null) return;
    try {
      await _supabase.from('event_registrations').delete().eq('event_id', event.id).eq('performer_id', userId);
      setState(() => _registeredEventIds.remove(event.id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Registration cancelled', AppColors.error));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Error: $e', AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);
    return Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Events', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          const Text('Register for upcoming events', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
        ]),
      ),
      Expanded(child: events.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: const Icon(Icons.event_outlined, color: AppColors.textHint, size: 36)),
            const SizedBox(height: 14),
            const Text('No events available', style: TextStyle(color: AppColors.textSub, fontSize: 15)),
          ]));
          }
          return RefreshIndicator(
            onRefresh: () async { ref.invalidate(eventsProvider); await _loadRegistrations(); },
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final e = items[i];
                final isRegistered = _registeredEventIds.contains(e.id);
                final canRegister = e.isActive || e.isUpcoming;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _Card(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 50, height: 50, decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.event_rounded, color: Colors.white, size: 26)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.title, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(e.location ?? 'Location TBD', style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 12),
                          const SizedBox(width: 4),
                          Expanded(child: Text(e.formattedStart, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        ]),
                        if (e.formattedEnd != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.schedule_rounded, color: AppColors.textHint, size: 12),
                            const SizedBox(width: 4),
                            Expanded(child: Text('End: ${e.formattedEnd!}', style: const TextStyle(color: AppColors.textHint, fontSize: 11), overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: e.isActive ? const Color(0xFFDCFCE7) : e.isUpcoming ? const Color(0xFFEEF2FF) : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(e.status.value, style: TextStyle(
                              color: e.isActive ? AppColors.accent : e.isUpcoming ? AppColors.primary : AppColors.textHint,
                              fontSize: 10, fontWeight: FontWeight.w600,
                            )),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                            child: Text('${e.votesPerUser} vote${e.votesPerUser == 1 ? '' : 's'}/student', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        // Registration deadline
                        if (e.registrationDeadline != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(
                              e.isRegistrationOpen ? Icons.how_to_reg_rounded : Icons.app_registration_rounded,
                              color: e.isRegistrationOpen ? const Color(0xFFD97706) : AppColors.error,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Expanded(child: Text(
                              e.isRegistrationOpen
                                  ? 'Register by: ${e.formattedRegistrationDeadline!}'
                                  : 'Registration closed: ${e.formattedRegistrationDeadline!}',
                              style: TextStyle(
                                color: e.isRegistrationOpen ? const Color(0xFFD97706) : AppColors.error,
                                fontSize: 10, fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )),
                          ]),
                        ],
                        // Voting deadline
                        if (e.votingDeadline != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(Icons.how_to_vote_rounded, color: e.isVotingOpen ? AppColors.accent : AppColors.textHint, size: 12),
                            const SizedBox(width: 4),
                            Expanded(child: Text(
                              e.isVotingOpen
                                  ? 'Voting closes: ${e.formattedVotingDeadline!}'
                                  : 'Voting closed: ${e.formattedVotingDeadline!}',
                              style: TextStyle(color: e.isVotingOpen ? AppColors.accent : AppColors.textHint, fontSize: 10, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            )),
                          ]),
                        ],
                      ])),
                    ]),
                    if (e.description != null && e.description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(e.description!, style: const TextStyle(color: AppColors.textSub, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    Row(children: [
                      // Registration status badge
                      if (isRegistered)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 14),
                            SizedBox(width: 5),
                            Text('Registered', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                          ]),
                        )
                      else if (!canRegister)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20)),
                          child: const Text('Registration closed', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                        ),
                      const Spacer(),
                      if (canRegister)
                        isRegistered
                            ? GestureDetector(
                                onTap: () => _unregister(e),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
                                  child: const Text('Cancel', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 13)),
                                ),
                              )
                            : GestureDetector(
                                onTap: _loadingRegs ? null : () => _register(e),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(22), boxShadow: AppColors.primaryShadow),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text('Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                                  ]),
                                ),
                              ),
                    ]),
                  ])),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => const Center(child: Text('Failed to load events', style: TextStyle(color: AppColors.textSub))),
      )),
    ]);
  }
}



// ─── Results ──────────────────────────────────────────────────────────────────

class _Results extends ConsumerStatefulWidget {
  const _Results({required this.user});
  final dynamic user;
  @override
  ConsumerState<_Results> createState() => _ResultsState();
}

class _ResultsState extends ConsumerState<_Results> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _feedback = [];
  bool _loadingFeedback = true;
  Map<String, dynamic>? _voteStats;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    setState(() => _loadingFeedback = true);
    try {
      final userId = widget.user?.id;
      if (userId == null) return;

      // Load feedback
      final fb = await _supabase
          .from('feedback')
          .select('id, rating, comment, created_at, event_id, events(title)')
          .eq('performer_id', userId)
          .order('created_at', ascending: false);

      // Load vote stats
      final votes = await _supabase
          .from('votes')
          .select('score, event_id, events(title)')
          .eq('performer_id', userId);

      final voteList = (votes as List).cast<Map<String, dynamic>>();
      final totalVotes = voteList.length;
      final avgScore = totalVotes == 0 ? 0.0
          : voteList.map((v) => v['score'] as int).reduce((a, b) => a + b) / totalVotes;

      if (mounted) {
        setState(() {
        _feedback = (fb as List).cast<Map<String, dynamic>>();
        _voteStats = {'total': totalVotes, 'avg': avgScore};
        _loadingFeedback = false;
      });
      }
    } catch (_) { if (mounted) setState(() => _loadingFeedback = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 0),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Results', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
              SizedBox(height: 2),
              Text('Your votes and feedback', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
            ])),
            GestureDetector(
              onTap: _loadData,
              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20)),
            ),
          ]),
          const SizedBox(height: 12),
          // Tab bar
          Container(
            height: 40,
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20)),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSub,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              tabs: [
                Tab(text: 'Votes${_voteStats != null ? ' (${_voteStats!['total']})' : ''}'),
                Tab(text: 'Feedback${_feedback.isNotEmpty ? ' (${_feedback.length})' : ''}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ]),
      ),
      Expanded(child: _loadingFeedback
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : TabBarView(controller: _tabCtrl, children: [
            // -- Votes tab --------------------------------------------------
            ListView(padding: const EdgeInsets.all(20), children: [
              // Stats card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.primaryShadow),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _VoteStat('${_voteStats?['total'] ?? 0}', 'Total Votes', Icons.how_to_vote_rounded),
                  Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                  _VoteStat('${(_voteStats?['avg'] as double? ?? 0.0).toStringAsFixed(1)}/5', 'Avg Score', Icons.star_rounded),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Score Distribution', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              ...List.generate(5, (i) {
                final score = 5 - i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    SizedBox(width: 20, child: Text('$score', style: const TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 4),
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
                      value: 0.3 + (score * 0.1),
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary.withValues(alpha: 0.6 + score * 0.08)),
                    ))),
                  ]),
                );
              }),
            ]),
            // -- Feedback tab -----------------------------------------------
            _feedback.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: const Icon(Icons.comment_outlined, color: AppColors.textHint, size: 36)),
                  const SizedBox(height: 14),
                  const Text('No feedback yet', style: TextStyle(color: AppColors.textSub, fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text('Students will leave reviews after voting', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _feedback.length,
                  itemBuilder: (_, i) {
                    final fb = _feedback[i];
                    final rating = fb['rating'] as int? ?? 0;
                    final comment = fb['comment'] as String? ?? '';
                    final eventTitle = (fb['events'] as Map?)?['title'] as String? ?? 'Unknown event';
                    final date = DateTime.tryParse(fb['created_at'] as String? ?? '');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Row(children: List.generate(5, (j) => Icon(j < rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF59E0B), size: 16))),
                          const Spacer(),
                          if (date != null) Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                        ]),
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(comment, style: const TextStyle(color: AppColors.textMain, fontSize: 14, height: 1.4)),
                        ],
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.event_rounded, color: AppColors.primary, size: 13),
                          const SizedBox(width: 4),
                          Text(eventTitle, style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
                        ]),
                      ]),
                    );
                  },
                ),
          ])),
    ]);
  }
}

class _VoteStat extends StatelessWidget {
  const _VoteStat(this.value, this.label, this.icon);
  final String value, label; final IconData icon;
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: Colors.white, size: 24),
    const SizedBox(height: 6),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
  ]);
}




// ─── Notifications (appended) ─────────────────────────────────────────────────

class _Notifications extends ConsumerStatefulWidget {
  const _Notifications({required this.user});
  final dynamic user;
  @override
  ConsumerState<_Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<_Notifications> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = widget.user?.id;
      if (userId == null) { setState(() => _loading = false); return; }
      final res = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
        _notifs = (res as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _markAllRead() async {
    try {
      final userId = widget.user?.id;
      if (userId == null) return;
      await _supabase.from('notifications').update({'is_read': true})
          .eq('user_id', userId).eq('is_read', false);
      _load();
    } catch (_) {}
  }

  Future<void> _markRead(String id) async {
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
      setState(() {
        final idx = _notifs.indexWhere((n) => n['id'] == id);
        if (idx != -1) _notifs[idx] = {..._notifs[idx], 'is_read': true};
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifs.where((n) => n['is_read'] == false).length;
    return Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notifications', style: TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w900)),
            if (unread > 0)
              Text('$unread unread', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
          if (unread > 0) ...[
            GestureDetector(
              onTap: _markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(20)),
                child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _notifs.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: const Icon(Icons.notifications_none_rounded, color: AppColors.textHint, size: 36)),
                    const SizedBox(height: 14),
                    const Text('No notifications yet', style: TextStyle(color: AppColors.textSub, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Text('You will be notified when students vote\nor leave feedback', style: TextStyle(color: AppColors.textHint, fontSize: 12), textAlign: TextAlign.center),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _notifs.length,
                      itemBuilder: (_, i) {
                        final n = _notifs[i];
                        final isRead = n['is_read'] as bool? ?? false;
                        final title = n['title'] as String? ?? '';
                        final message = n['message'] as String? ?? '';
                        final type = n['type'] as String? ?? 'info';
                        final createdAt = DateTime.tryParse(n['created_at'] as String? ?? '');
                        final typeColors = <String, Color>{
                          'success': AppColors.accent,
                          'error': AppColors.error,
                          'warning': const Color(0xFFD97706),
                          'info': AppColors.primary,
                        };
                        final typeIcons = <String, IconData>{
                          'success': Icons.check_circle_rounded,
                          'error': Icons.error_rounded,
                          'warning': Icons.warning_rounded,
                          'info': Icons.notifications_rounded,
                        };
                        final color = typeColors[type] ?? AppColors.primary;
                        final icon = typeIcons[type] ?? Icons.notifications_rounded;
                        return GestureDetector(
                          onTap: () => _markRead(n['id'] as String),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isRead ? AppColors.surface : const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.25)),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Row(children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: isRead ? AppColors.surfaceAlt : color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: isRead ? AppColors.border : color.withValues(alpha: 0.3)),
                                ),
                                child: Icon(icon, color: isRead ? AppColors.textHint : color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(title, style: TextStyle(color: AppColors.textMain, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(message, style: const TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ])),
                              const SizedBox(width: 8),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                if (!isRead) Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                if (createdAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: AppColors.textHint, fontSize: 10),
                                  ),
                                ],
                              ]),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}

