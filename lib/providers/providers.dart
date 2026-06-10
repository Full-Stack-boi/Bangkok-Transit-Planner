import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/transit_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/crowd_repository.dart';
import '../services/fare_service.dart';
import '../services/schedule_service.dart';
import '../services/crowd_service.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';

// ─── Repository Providers ───

final transitRepositoryProvider = Provider<TransitRepository>((ref) {
  return TransitRepository();
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return FavoritesRepository(supabase);
});

final crowdRepositoryProvider = Provider<CrowdRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return CrowdRepository(supabase);
});

// ─── Service Providers ───

final fareServiceProvider = Provider<FareService>((ref) {
  return FareService();
});

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService();
});

final crowdServiceProvider = Provider<CrowdService>((ref) {
  return CrowdService();
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// ─── Initialization Provider ───

/// Initializes transit data (loads JSON, builds graph), Supabase, and Favorites
final transitInitProvider = FutureProvider<void>((ref) async {
  final supabase = ref.read(supabaseServiceProvider);
  await supabase.initialize();

  final favorites = ref.read(favoritesRepositoryProvider);
  await favorites.initialize();

  final repo = ref.read(transitRepositoryProvider);
  await repo.initialize();
});

// ─── UI Providers ───

final homeTabIndexProvider = StateProvider<int>((ref) => 0);
