import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Repository for handling all Authentication actions via Supabase Auth & Google Sign-In
class AuthRepository {
  final SupabaseService _supabaseService;

  AuthRepository(this._supabaseService);

  SupabaseClient? get _client => _supabaseService.client;

  /// Current user in the active Supabase session
  User? get currentUser => _client?.auth.currentUser;

  /// Stream of authentication state changes
  Stream<AuthState> get onAuthStateChanged {
    if (_client == null) {
      return const Stream.empty();
    }
    return _client!.auth.onAuthStateChange;
  }

  /// Sign up a new user using Email & Password, storing metadata like display_name
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not initialized');
    }

    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
        },
      );
      return response;
    } catch (e) {
      print('Sign up error in AuthRepository: $e');
      rethrow;
    }
  }

  /// Sign in an existing user with Email & Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not initialized');
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      print('Sign in error in AuthRepository: $e');
      rethrow;
    }
  }

  /// Sign in natively using Google SDK and pass ID token to Supabase
  Future<AuthResponse?> signInWithGoogle() async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not initialized');
    }

    try {
      // Ensure Google Sign-In is initialized with the Web client ID as serverClientId
      await GoogleSignIn.instance.initialize(
        serverClientId: '1010460816238-0q8gpanpmepu2g457mh1kb7124e1jn0b.apps.googleusercontent.com',
      );

      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      
      // Explicitly request access token by authorizing scopes
      final clientAuth = await googleUser.authorizationClient.authorizeScopes(['email', 'profile']);
      final accessToken = clientAuth.accessToken;

      if (idToken == null) {
        throw Exception('Google Sign-In failed: missing ID Token.');
      }

      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return response;
    } catch (e) {
      print('Native Google Sign-In error in AuthRepository: $e');
      rethrow;
    }
  }

  /// Sign out the current user session
  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.auth.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      print('Sign out error in AuthRepository: $e');
    }
  }

  /// Fetch user profile details from the custom public.profiles table
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final data = await client
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      return data;
    } catch (e) {
      print('Failed to load profile in AuthRepository: $e');
      return null;
    }
  }

  /// Update the authenticated user's card preferences in Supabase userMetadata
  Future<void> updateUserCards({
    required String btsCardType,
    required String mrtCardType,
    required String arlCardType,
    required String srtCardType,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.auth.updateUser(
        UserAttributes(
          data: {
            'bts_card_type': btsCardType,
            'mrt_card_type': mrtCardType,
            'arl_card_type': arlCardType,
            'srt_card_type': srtCardType,
          },
        ),
      );
    } catch (e) {
      print('Failed to update user cards metadata: $e');
    }
  }
}
