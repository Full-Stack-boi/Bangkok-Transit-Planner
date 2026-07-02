import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_providers.dart';

/// State representation for the user's transit cards and subscriptions
class UserCardsState {
  final String btsCardType; // 'standard', 'student', 'senior', 'trip_package'
  final String mrtCardType; // 'standard', 'student', 'senior'
  final String arlCardType; // 'standard', 'student', 'senior'
  final String srtCardType; // 'standard', 'student', 'senior'

  const UserCardsState({
    this.btsCardType = 'standard',
    this.mrtCardType = 'standard',
    this.arlCardType = 'standard',
    this.srtCardType = 'standard',
  });

  UserCardsState copyWith({
    String? btsCardType,
    String? mrtCardType,
    String? arlCardType,
    String? srtCardType,
  }) {
    return UserCardsState(
      btsCardType: btsCardType ?? this.btsCardType,
      mrtCardType: mrtCardType ?? this.mrtCardType,
      arlCardType: arlCardType ?? this.arlCardType,
      srtCardType: srtCardType ?? this.srtCardType,
    );
  }
}

/// Notifier that manages transit card state, persistence in SharedPreferences,
/// and cloud synchronization via Supabase User Metadata when authenticated.
class UserCardsNotifier extends Notifier<UserCardsState> {
  @override
  UserCardsState build() {
    _loadCards();
    return const UserCardsState();
  }

  /// Load cards from SharedPreferences on initialization
  Future<void> _loadCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bts = prefs.getString('bts_card_type') ?? 'standard';
      final mrt = prefs.getString('mrt_card_type') ?? 'standard';
      final arl = prefs.getString('arl_card_type') ?? 'standard';
      final srt = prefs.getString('srt_card_type') ?? 'standard';
      state = UserCardsState(
        btsCardType: bts,
        mrtCardType: mrt,
        arlCardType: arl,
        srtCardType: srt,
      );
    } catch (_) {}
  }

  /// Set the card type for a specific transit network ('BTS', 'MRT', 'ARL', or 'SRT')
  Future<void> setCardType(String network, String type) async {
    UserCardsState newState;
    if (network == 'BTS') {
      newState = state.copyWith(btsCardType: type);
    } else if (network == 'MRT') {
      newState = state.copyWith(mrtCardType: type);
    } else if (network == 'ARL') {
      newState = state.copyWith(arlCardType: type);
    } else if (network == 'SRT') {
      newState = state.copyWith(srtCardType: type);
    } else {
      return;
    }

    state = newState;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${network.toLowerCase()}_card_type', type);
    } catch (_) {}

    // Sync with Supabase in background if logged in
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      final repository = ref.read(authRepositoryProvider);
      await repository.updateUserCards(
        btsCardType: state.btsCardType,
        mrtCardType: state.mrtCardType,
        arlCardType: state.arlCardType,
        srtCardType: state.srtCardType,
      );
    }
  }

  /// Sync state from cloud database/metadata (called by auth listener on login)
  void updateFromSync({
    required String btsCardType,
    required String mrtCardType,
    required String arlCardType,
    required String srtCardType,
  }) {
    state = UserCardsState(
      btsCardType: btsCardType,
      mrtCardType: mrtCardType,
      arlCardType: arlCardType,
      srtCardType: srtCardType,
    );

    // Persist locally
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('bts_card_type', btsCardType);
      prefs.setString('mrt_card_type', mrtCardType);
      prefs.setString('arl_card_type', arlCardType);
      prefs.setString('srt_card_type', srtCardType);
    }).catchError((_) {});
  }
}

/// Provider exposing the active user card settings
final userCardsProvider = NotifierProvider<UserCardsNotifier, UserCardsState>(() {
  return UserCardsNotifier();
});
