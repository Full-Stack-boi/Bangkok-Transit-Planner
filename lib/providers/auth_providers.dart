import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import 'providers.dart';
import '../features/favorites/favorites_view_model.dart';

part 'auth_providers.g.dart';

/// State object representing the current user's session and profile information
class AuthState {
  final User? user;
  final String? displayName;
  final String? avatarUrl;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.displayName,
    this.avatarUrl,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    String? displayName,
    String? avatarUrl,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      displayName: clearUser ? null : (displayName ?? this.displayName),
      avatarUrl: clearUser ? null : (avatarUrl ?? this.avatarUrl),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Provider exposing the AuthRepository instance
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepository(supabaseService);
});

/// Notifier that handles auth logic, captures session changes, and fetches user profiles
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    // Listen to Supabase authentication changes
    final subscription = repository.onAuthStateChanged.listen((data) async {
      final user = data.session?.user;
      if (user != null) {
        if (!ref.mounted) return;
        state = state.copyWith(user: user, isLoading: true);
        final profile = await repository.getUserProfile(user.id);
        
        if (!ref.mounted) return;
        state = state.copyWith(
          displayName: profile?['display_name'] as String?,
          avatarUrl: profile?['avatar_url'] as String?,
          isLoading: false,
        );

        // Perform offline sync to upload locally saved routes and favorites
        try {
          final favoritesRepo = ref.read(favoritesRepositoryProvider);
          await favoritesRepo.syncOfflineDataWithSupabase();
          
          if (!ref.mounted) return;
          // Refresh favorites screen view model to load updated synced listings
          ref.read(favoritesViewModelProvider.notifier).refresh();
        } catch (e) {
          print('Background sync failed on login: $e');
        }
      } else {
        if (!ref.mounted) return;
        // Logged out
        state = const AuthState();
        // Refresh to clear synced lists/restore local listings
        ref.read(favoritesViewModelProvider.notifier).refresh();
      }
    });

    ref.onDispose(subscription.cancel);

    return const AuthState();
  }

  /// Sign in with Email & Password
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signIn(email: email, password: password);
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
      return false;
    }
  }

  /// Register/Sign up with Email, Password and a Display Name
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
      return false;
    }
  }

  /// Login with Google Single Sign-On
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      final response = await repository.signInWithGoogle();
      return response != null;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
      return false;
    }
  }

  /// Logout of current session
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    final repository = ref.read(authRepositoryProvider);
    await repository.signOut();
  }
}
