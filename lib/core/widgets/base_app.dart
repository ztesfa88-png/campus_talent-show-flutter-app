import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../routing/app_router.dart';
import '../providers/app_data_provider.dart';

class BaseApp extends ConsumerWidget {
  const BaseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Campus Talent Show',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => _LifecycleWrapper(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Listens for app lifecycle changes and triggers offline queue sync
/// whenever the app comes back to the foreground.
class _LifecycleWrapper extends ConsumerStatefulWidget {
  const _LifecycleWrapper({required this.child});
  final Widget child;

  @override
  ConsumerState<_LifecycleWrapper> createState() => _LifecycleWrapperState();
}

class _LifecycleWrapperState extends ConsumerState<_LifecycleWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Attempt sync on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(syncProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — try to sync queued actions
      ref.invalidate(syncProvider);
      // Also refresh pending count badge
      ref.invalidate(pendingCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
