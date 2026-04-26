import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../models/user.dart' as app_user;
import '../models/user.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthService {
  static const String _localAdminSessionKey = 'local_admin_session_v1';
  // Admin credentials — stored locally, never sent to Supabase
  static const String _localAdminEmail = 'admin@gmail.com';
  static const String _localAdminPassword = 'admin123';

  final supa.SupabaseClient _supabase = supa.Supabase.instance.client;
  app_user.User? _currentUser;
  bool _isLocalAdminSession = false;

  app_user.User? get currentUser => _currentUser;
  UserRole? get currentUserRole => _currentUser?.role;
  bool get isAuthenticated => _currentUser != null;

  AuthService() {
    _initializeAuth();
  }

  Future<app_user.User?> initializeAuthState() async {
    await _initializeAuth();
    return _currentUser;
  }

  Future<void> _initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLocalAdminSession = prefs.getBool(_localAdminSessionKey) ?? false;
      if (_isLocalAdminSession) {
        _currentUser = _buildLocalAdmin();
        return;
      }
      final supaUser = _supabase.auth.currentSession?.user ?? _supabase.auth.currentUser;
      if (supaUser != null) {
        _currentUser = await _loadUserProfile(supaUser);
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
    }
  }

  Future<app_user.User?> signInWithEmail(String email, String password) async {
    // ── Local admin check (always first, before any network call) ──────────
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedPass = password.trim();

    if (trimmedEmail == _localAdminEmail.toLowerCase() &&
        trimmedPass == _localAdminPassword) {
      _isLocalAdminSession = true;
      _currentUser = _buildLocalAdmin();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localAdminSessionKey, true);
      debugPrint('Local admin signed in');
      return _currentUser;
    }

    // ── Supabase sign-in ────────────────────────────────────────────────────
    try {
      debugPrint('signInWithEmail: $trimmedEmail');
      final response = await _supabase.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );
      debugPrint('signIn response: user=${response.user?.id} session=${response.session != null}');
      if (response.user == null) {
        throw Exception('Invalid email or password');
      }
      _isLocalAdminSession = false;
      await _ensureUserProfile(
        supabaseUser: response.user!,
        fallbackName: response.user!.userMetadata?['name'] as String?,
        fallbackRole: UserRole.fromString(
          (response.user!.userMetadata?['role'] as String?) ?? 'student',
        ),
      );
      _currentUser = await _loadUserProfile(response.user!);
      return _currentUser;
    } on supa.AuthException catch (e) {
      // Provide a cleaner error message for email-not-confirmed
      if (e.message.toLowerCase().contains('email not confirmed') ||
          e.message.toLowerCase().contains('not confirmed')) {
        throw Exception(
            'Email not confirmed. Please check your inbox and click the verification link, or contact admin to disable email confirmation.');
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<app_user.User?> signUpWithEmail(
    String email,
    String password,
    String name,
    UserRole role,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint('signUpWithEmail: $normalizedEmail role=${role.value}');

    // ── Attempt 1: Normal Supabase signUp ────────────────────────────────────
    supa.AuthResponse? response;
    try {
      response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'name': name, 'role': role.value},
      );
      debugPrint('signUp response: user=${response.user?.id} session=${response.session != null}');
    } on supa.AuthException catch (e) {
      debugPrint('signUp AuthException: ${e.message} code=${e.statusCode}');

      // ── 500 = broken trigger. Try to sign in — user may have been created ──
      if (e.statusCode == '500' || e.message.contains('Database error')) {
        debugPrint('Trigger error — attempting sign-in as workaround...');
        try {
          final signInResult = await signInWithEmail(normalizedEmail, password);
          if (signInResult != null) return signInResult;
        } catch (_) {}

        // User wasn't created at all — give a clear actionable message
        throw Exception(
          'Registration failed due to a database configuration issue.\n\n'
          'Please ask your admin to run this SQL in Supabase Dashboard → SQL Editor:\n\n'
          'CREATE OR REPLACE FUNCTION public.handle_new_user()\n'
          'RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER\n'
          'SET search_path = public AS \$\$\n'
          'BEGIN\n'
          '  INSERT INTO public.users(id,email,name,role,created_at,updated_at)\n'
          '  VALUES(NEW.id,NEW.email,\n'
          '    COALESCE(NEW.raw_user_meta_data->>\'name\',split_part(NEW.email,\'@\',1)),\n'
          '    COALESCE(NEW.raw_user_meta_data->>\'role\',\'student\'),NOW(),NOW())\n'
          '  ON CONFLICT(id) DO UPDATE SET\n'
          '    email=EXCLUDED.email,updated_at=NOW();\n'
          '  RETURN NEW;\n'
          'END;\n'
          '\$\$;\n\n'
          'DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;\n'
          'CREATE TRIGGER on_auth_user_created\n'
          '  AFTER INSERT ON auth.users FOR EACH ROW\n'
          '  EXECUTE FUNCTION public.handle_new_user();',
        );
      }
      throw Exception(e.message);
    } catch (e) {
      debugPrint('signUp error: $e');
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }

    if (response.user == null) {
      throw Exception('Failed to create account');
    }

    // ── No session = email confirmation required ──────────────────────────────
    if (response.session == null) {
      try {
        return await signInWithEmail(normalizedEmail, password);
      } on Exception {
        throw Exception(
            'Account created! Check your email for a verification link, then sign in.');
      }
    }

    // ── Session exists — create profile rows ──────────────────────────────────
    await _ensureUserProfile(
      supabaseUser: response.user!,
      fallbackName: name,
      fallbackRole: role,
    );

    _isLocalAdminSession = false;
    _currentUser = await _loadUserProfile(response.user!);
    debugPrint('signUp complete: user=${_currentUser?.id} role=${_currentUser?.role.value}');
    return _currentUser;
  }

  Future<void> signOut() async {
    try {
      _currentUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localAdminSessionKey);
      _isLocalAdminSession = false;
      if (_supabase.auth.currentSession != null) {
        await _supabase.auth.signOut();
      }
    } catch (e) {
      debugPrint('Sign out error: $e');
      throw Exception('Failed to sign out');
    }
  }

  Future<void> resetPassword(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail == _localAdminEmail.toLowerCase()) {
      throw Exception('Admin password is managed locally and cannot be reset via email.');
    }
    try {
      await _supabase.auth.resetPasswordForEmail(normalizedEmail);
    } on supa.AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  app_user.User _mapSupabaseUser(supa.User user) {
    final metadata = user.userMetadata ?? <String, dynamic>{};
    return app_user.User(
      id: user.id,
      email: user.email ?? '',
      name: metadata['name'] as String?,
      role: UserRole.fromString((metadata['role'] as String?) ?? 'student'),
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _ensureUserProfile({
    required supa.User supabaseUser,
    required String? fallbackName,
    required UserRole fallbackRole,
  }) async {
    // NOTE: The Supabase trigger handle_new_user() already inserts into public.users
    // We only need to handle the performers table here (trigger doesn't do that by default)
    final metadata = supabaseUser.userMetadata ?? <String, dynamic>{};
    final roleStr = (metadata['role'] as String?) ?? fallbackRole.value;
    final role = UserRole.fromString(roleStr);

    // Only upsert users table if trigger might not have run (e.g. on sign-in)
    try {
      final existing = await _supabase
          .from('users')
          .select('id')
          .eq('id', supabaseUser.id)
          .maybeSingle();

      if (existing == null) {
        // Trigger didn't create the row — insert manually
        await _supabase.from('users').insert({
          'id': supabaseUser.id,
          'email': supabaseUser.email ?? '',
          'name': (metadata['name'] as String?) ?? fallbackName,
          'role': roleStr,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('users insert OK (trigger missed) for ${supabaseUser.id}');
      } else {
        // Row exists — just update name/role if needed
        await _supabase.from('users').update({
          'name': (metadata['name'] as String?) ?? fallbackName,
          'role': roleStr,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', supabaseUser.id);
        debugPrint('users update OK for ${supabaseUser.id}');
      }
    } catch (e) {
      debugPrint('users ensure error (non-fatal): $e');
    }

    // Ensure performers row exists for performer role
    if (role == UserRole.performer) {
      try {
        final existingPerformer = await _supabase
            .from('performers')
            .select('id')
            .eq('id', supabaseUser.id)
            .maybeSingle();

        if (existingPerformer == null) {
          await _supabase.from('performers').insert({
            'id': supabaseUser.id,
            'talent_type': 'other',
            'experience_level': 'beginner',
            'social_links': <String, dynamic>{},
          });
          debugPrint('performers insert OK for ${supabaseUser.id}');
        }
      } catch (e) {
        debugPrint('performers ensure error (non-fatal): $e');
      }
    }
  }

  Future<app_user.User> _loadUserProfile(supa.User supabaseUser) async {
    try {
      final profile = await _supabase
          .from('users')
          .select()
          .eq('id', supabaseUser.id)
          .single();
      return app_user.User.fromJson(Map<String, dynamic>.from(profile));
    } catch (_) {
      return _mapSupabaseUser(supabaseUser);
    }
  }

  app_user.User _buildLocalAdmin() {
    return app_user.User(
      id: 'local-predefined-admin',
      email: _localAdminEmail,
      name: 'System Admin',
      role: UserRole.admin,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime.now(),
    );
  }
}
