import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _index = 0;
  late final AnimationController _floatCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double> _floatAnim;
  late final Animation<double> _enterFade;
  late final Animation<Offset> _enterSlide;

  static const _pages = [_Page.discover, _Page.vote, _Page.celebrate];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _floatAnim = CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut);
    _enterFade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _floatCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _enterCtrl.reset();
    _enterCtrl.forward();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: page.bgColors,
          ),
        ),
        child: Stack(
          children: [
            // ── Animated background shapes ──────────────────────────────────
            ..._buildBgShapes(page, size),

            SafeArea(
              child: Column(
                children: [
                  // ── Top bar ───────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Page indicator pills
                        Row(
                          children: List.generate(_pages.length, (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            height: 6,
                            width: _index == i ? 24 : 6,
                            decoration: BoxDecoration(
                              color: _index == i ? Colors.white : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          )),
                        ),
                        TextButton(
                          onPressed: _finish,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Illustration area ─────────────────────────────────────
                  Expanded(
                    flex: 5,
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: _pages.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (_, i) => _PageIllustration(
                        page: _pages[i],
                        floatAnim: _floatAnim,
                        isActive: i == _index,
                      ),
                    ),
                  ),

                  // ── Text content ──────────────────────────────────────────
                  Expanded(
                    flex: 4,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(36),
                          topRight: Radius.circular(36),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tag
                            FadeTransition(
                              opacity: _enterFade,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: page.accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  page.tag,
                                  style: TextStyle(
                                    color: page.accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Title
                            SlideTransition(
                              position: _enterSlide,
                              child: FadeTransition(
                                opacity: _enterFade,
                                child: Text(
                                  page.title,
                                  style: const TextStyle(
                                    color: AppColors.textMain,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Subtitle
                            FadeTransition(
                              opacity: _enterFade,
                              child: Text(
                                page.subtitle,
                                style: const TextStyle(
                                  color: AppColors.textSub,
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Buttons
                            Row(
                              children: [
                                if (_index > 0) ...[
                                  GestureDetector(
                                    onTap: () => _pageCtrl.previousPage(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                    ),
                                    child: Container(
                                      width: 52, height: 52,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: const Icon(Icons.arrow_back_rounded, color: AppColors.textSub, size: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _index == _pages.length - 1
                                        ? _finish
                                        : () => _pageCtrl.nextPage(
                                            duration: const Duration(milliseconds: 400),
                                            curve: Curves.easeInOut,
                                          ),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      height: 54,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [page.accentColor, page.accentColor.withValues(alpha: 0.8)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: page.accentColor.withValues(alpha: 0.4),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          _index == _pages.length - 1 ? 'Get Started 🚀' : 'Continue',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBgShapes(_Page page, Size size) {
    return [
      // Large circle top-right
      Positioned(
        top: -size.width * 0.25,
        right: -size.width * 0.2,
        child: Container(
          width: size.width * 0.7,
          height: size.width * 0.7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      // Medium circle bottom-left
      Positioned(
        bottom: size.height * 0.3,
        left: -size.width * 0.15,
        child: Container(
          width: size.width * 0.5,
          height: size.width * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      // Small accent circle
      Positioned(
        top: size.height * 0.15,
        left: size.width * 0.1,
        child: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
      ),
      // Tiny dot
      Positioned(
        top: size.height * 0.28,
        right: size.width * 0.12,
        child: Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
      ),
    ];
  }
}

// ─── Page Illustration ────────────────────────────────────────────────────────

class _PageIllustration extends StatelessWidget {
  const _PageIllustration({
    required this.page,
    required this.floatAnim,
    required this.isActive,
  });

  final _Page page;
  final Animation<double> floatAnim;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: floatAnim,
        builder: (_, child) {
          final offset = isActive ? (floatAnim.value * 14 - 7) : 0.0;
          return Transform.translate(
            offset: Offset(0, offset),
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            // Middle ring
            Container(
              width: 170, height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            // Main icon container
            Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(page.emoji, style: const TextStyle(fontSize: 52)),
                ],
              ),
            ),
            // Floating mini badges
            ...page.badges.asMap().entries.map((e) {
              final angle = (e.key / page.badges.length) * 2 * math.pi - math.pi / 4;
              final radius = 105.0;
              return Positioned(
                left: 110 + radius * math.cos(angle) - 20,
                top: 110 + radius * math.sin(angle) - 20,
                child: AnimatedBuilder(
                  animation: floatAnim,
                  builder: (_, child) {
                    final delay = e.key * 0.3;
                    final t = (floatAnim.value + delay) % 1.0;
                    final yOff = math.sin(t * math.pi * 2) * 5;
                    return Transform.translate(offset: Offset(0, yOff), child: child);
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(child: Text(e.value, style: const TextStyle(fontSize: 20))),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Page Data ────────────────────────────────────────────────────────────────

class _Page {
  const _Page({
    required this.bgColors,
    required this.accentColor,
    required this.emoji,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.badges,
  });

  final List<Color> bgColors;
  final Color accentColor;
  final String emoji, tag, title, subtitle;
  final List<String> badges;

  static const discover = _Page(
    bgColors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    accentColor: Color(0xFF6366F1),
    emoji: '🎵',
    tag: 'DISCOVER',
    title: 'Discover Campus\nTalent',
    subtitle: 'Explore amazing performers across music, dance, comedy and more. Find your next favorite artist on campus!',
    badges: ['🎸', '💃', '🎭', '✨'],
  );

  static const vote = _Page(
    bgColors: [Color(0xFF0EA5E9), Color(0xFF6366F1), Color(0xFF8B5CF6)],
    accentColor: Color(0xFF0EA5E9),
    emoji: '🗳️',
    tag: 'VOTE',
    title: 'Vote for Your\nFavorites',
    subtitle: 'Cast secure votes with real-time leaderboard updates. Watch rankings change live as votes pour in!',
    badges: ['⭐', '🏆', '📊', '🔥'],
  );

  static const celebrate = _Page(
    bgColors: [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF15803D)],
    accentColor: Color(0xFF22C55E),
    emoji: '🏆',
    tag: 'CELEBRATE',
    title: 'Celebrate &\nEngage',
    subtitle: 'Rate performers, leave comments, and get live notifications. Be part of the campus talent community!',
    badges: ['💬', '🎉', '🔔', '❤️'],
  );
}
