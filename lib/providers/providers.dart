import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/transit_repository.dart';
import '../services/fare_service.dart';
import '../services/schedule_service.dart';
import '../services/crowd_service.dart';

// ─── Repository Providers ───

final transitRepositoryProvider = Provider<TransitRepository>((ref) {
  return TransitRepository();
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

// ─── Initialization Provider ───

/// Initializes transit data (loads JSON, builds graph)
final transitInitProvider = FutureProvider<void>((ref) async {
  final repo = ref.read(transitRepositoryProvider);
  await repo.initialize();
});
