import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/auth/onboarding_screen.dart';
import '../../presentation/screens/auth/splash_screen.dart';
import '../../presentation/screens/admin/admin_app_shell.dart';
import '../../presentation/screens/performers/performer_app_shell.dart';
import '../../presentation/screens/student/student_app_shell.dart';
import '../../core/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // Don't redirect while still initializing
      if (authState.isInitializing) return null;

      final isAuthenticated = authState.user != null;
      final currentPath = state.uri.path;

      final isAuthRoute = currentPath.startsWith('/login') ||
          currentPath.startsWith('/register') ||
          currentPath.startsWith('/onboarding') ||
          currentPath.startsWith('/splash');

      if (!isAuthenticated) {
        // Allow auth routes through; redirect everything else to login
        return isAuthRoute ? null : '/login';
      }

      // Authenticated — redirect away from auth routes to the right shell
      if (isAuthRoute) {
        switch (authState.user?.role.value) {
          case 'admin':
            return '/admin';
          case 'performer':
            return '/performer';
          default:
            return '/student';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Authentication routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // Admin routes
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminAppShell(),
      ),
      
      // Performer routes
      GoRoute(
        path: '/performer',
        builder: (context, state) => const PerformerAppShell(),
      ),
      
      // Student routes
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentAppShell(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri.path}'),
      ),
    ),
  );
});
