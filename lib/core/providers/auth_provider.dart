import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/user.dart';

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthStateNotifier(authService);
});

class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthStateNotifier(this._authService) : super(const AuthState.initial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final user = await _authService.initializeAuthState();
    if (user != null) {
      state = AuthState.authenticated(user);
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AuthState.loading();
    try {
      final user = await _authService.signInWithEmail(email, password);
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.error('Failed to sign in');
      }
    } catch (e) {
      state = AuthState.error(_cleanError(e));
    }
  }

  Future<void> signUp(String email, String password, String name, UserRole role) async {
    state = const AuthState.loading();
    try {
      final user = await _authService.signUpWithEmail(email, password, name, role);
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.error('Failed to sign up');
      }
    } catch (e) {
      state = AuthState.error(_cleanError(e));
    }
  }

  Future<void> signOut() async {
    state = const AuthState.loading();
    try {
      await _authService.signOut();
      state = const AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error(_cleanError(e));
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      state = AuthState.error(_cleanError(e));
    }
  }

  String _cleanError(Object e) {
    return e.toString().replaceFirst('Exception: ', '').trim();
  }
}

class AuthState {
  final bool isLoading;
  final bool isInitializing; // true only during app startup
  final User? user;
  final String? error;

  const AuthState._({
    this.isLoading = false,
    this.isInitializing = false,
    this.user,
    this.error,
  });

  const AuthState.initial() : this._(isInitializing: true);

  const AuthState.loading() : this._(isLoading: true);

  const AuthState.authenticated(User user) : this._(user: user);

  const AuthState.unauthenticated() : this._();

  const AuthState.error(String error) : this._(error: error);

  bool get isAuthenticated => user != null;
  bool get isUnauthenticated => user == null && !isLoading && !isInitializing;
  bool get hasError => error != null;
}
