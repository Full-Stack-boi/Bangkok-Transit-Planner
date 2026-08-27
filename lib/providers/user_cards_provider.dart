import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/logger.dart';
import '../models/transit_enums.dart';
import 'auth_providers.dart';

part 'user_cards_provider.g.dart';

/// State representation for the user's transit cards and subscriptions
class UserCardsState {
  final TransitCardType btsCardType;
  final TransitCardType mrtCardType;
  final TransitCardType arlCardType;
  final TransitCardType srtCardType;

  const UserCardsState({
    this.btsCardType = TransitCardType.standard,
    this.mrtCardType = TransitCardType.standard,
    this.arlCardType = TransitCardType.standard,
    this.srtCardType = TransitCardType.standard,
  });

  /// Get the active card type for a given transit network
  TransitCardType forNetwork(TransitNetwork network) {
    switch (network) {
      case TransitNetwork.bts:
        return btsCardType;
      case TransitNetwork.mrt:
        return mrtCardType;
      case TransitNetwork.arl:
        return arlCardType;
      case TransitNetwork.srt:
        return srtCardType;
    }
  }

  UserCardsState copyWith({
    TransitCardType? btsCardType,
    TransitCardType? mrtCardType,
    TransitCardType? arlCardType,
    TransitCardType? srtCardType,
  }) {
    return UserCardsState(
      btsCardType: btsCardType ?? this.btsCardType,
      mrtCardType: mrtCardType ?? this.mrtCardType,
      arlCardType: arlCardType ?? this.arlCardType,
      srtCardType: srtCardType ?? this.srtCardType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserCardsState &&
          runtimeType == other.runtimeType &&
          btsCardType == other.btsCardType &&
          mrtCardType == other.mrtCardType &&
          arlCardType == other.arlCardType &&
          srtCardType == other.srtCardType;

  @override
  int get hashCode =>
      btsCardType.hashCode ^
      mrtCardType.hashCode ^
      arlCardType.hashCode ^
      srtCardType.hashCode;
}

/// Notifier that manages transit card state, persistence in SharedPreferences,
/// and cloud synchronization via Supabase User Metadata when authenticated.
@riverpod
class UserCards extends _$UserCards {
  @override
  UserCardsState build() {
    _loadCards();
    return const UserCardsState();
  }

  /// Load cards from SharedPreferences on initialization
  Future<void> _loadCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bts = TransitCardType.fromJson(prefs.getString('bts_card_type'));
      final mrt = TransitCardType.fromJson(prefs.getString('mrt_card_type'));
      final arl = TransitCardType.fromJson(prefs.getString('arl_card_type'));
      final srt = TransitCardType.fromJson(prefs.getString('srt_card_type'));
      state = UserCardsState(
        btsCardType: bts,
        mrtCardType: mrt,
        arlCardType: arl,
        srtCardType: srt,
      );
    } catch (e, st) {
      AppLogger.warning('Failed to load card preferences from local storage: $e', stackTrace: st);
    }
  }

  /// Set the card type for a specific transit network
  Future<void> setCardType(TransitNetwork network, TransitCardType type) async {
    UserCardsState newState;
    switch (network) {
      case TransitNetwork.bts:
        newState = state.copyWith(btsCardType: type);
        break;
      case TransitNetwork.mrt:
        newState = state.copyWith(mrtCardType: type);
        break;
      case TransitNetwork.arl:
        newState = state.copyWith(arlCardType: type);
        break;
      case TransitNetwork.srt:
        newState = state.copyWith(srtCardType: type);
        break;
    }

    state = newState;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${network.key.toLowerCase()}_card_type', type.toJson());
    } catch (e, st) {
      AppLogger.warning('Failed to persist card preference for ${network.key}: $e', stackTrace: st);
    }

    // Sync with Supabase in background if logged in
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      final repository = ref.read(authRepositoryProvider);
      await repository.updateUserCards(
        btsCardType: state.btsCardType.toJson(),
        mrtCardType: state.mrtCardType.toJson(),
        arlCardType: state.arlCardType.toJson(),
        srtCardType: state.srtCardType.toJson(),
      );
    }
  }

  /// Sync state from cloud database/metadata (called by auth listener on login)
  void updateFromSync({
    required TransitCardType btsCardType,
    required TransitCardType mrtCardType,
    required TransitCardType arlCardType,
    required TransitCardType srtCardType,
  }) {
    state = UserCardsState(
      btsCardType: btsCardType,
      mrtCardType: mrtCardType,
      arlCardType: arlCardType,
      srtCardType: srtCardType,
    );

    // Persist locally
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setString('bts_card_type', btsCardType.toJson());
          prefs.setString('mrt_card_type', mrtCardType.toJson());
          prefs.setString('arl_card_type', arlCardType.toJson());
          prefs.setString('srt_card_type', srtCardType.toJson());
        })
        .catchError((e, st) {
          AppLogger.warning('Failed to persist synced cards to local storage: $e', stackTrace: st);
        });
  }
}

