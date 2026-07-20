import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';

void main() {
  test('MRT Pink and SRT Red lines are loaded in debug mode', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize();

    // kDebugMode is true in unit tests
    expect(kDebugMode, isTrue);

    // Check if new lines are loaded
    final pinkLine = repo.lines.where((l) => l.id == 'MRT_PINK');
    final srtRedNorth = repo.lines.where((l) => l.id == 'SRT_RED_NORTH');
    final srtRedWest = repo.lines.where((l) => l.id == 'SRT_RED_WEST');

    expect(
      pinkLine,
      isNotEmpty,
      reason: 'MRT Pink line should be loaded in debug mode',
    );
    expect(
      srtRedNorth,
      isNotEmpty,
      reason: 'SRT Red North line should be loaded in debug mode',
    );
    expect(
      srtRedWest,
      isNotEmpty,
      reason: 'SRT Red West line should be loaded in debug mode',
    );

    // Check if some stations are loaded
    final pk01 = repo.stations.where((s) => s.id == 'MRT_PK01');
    final rn01 = repo.stations.where((s) => s.id == 'SRT_RN01');
    final rw01 = repo.stations.where((s) => s.id == 'SRT_RW01');

    expect(pk01, isNotEmpty, reason: 'MRT PK01 should be loaded in debug mode');
    expect(rn01, isNotEmpty, reason: 'SRT RN01 should be loaded in debug mode');
    expect(rw01, isNotEmpty, reason: 'SRT RW01 should be loaded in debug mode');

    // Check if exits are loaded
    final pk01Exits = repo.exits.where((e) => e.stationId == 'MRT_PK01');
    expect(
      pk01Exits,
      isNotEmpty,
      reason: 'MRT PK01 exits should be loaded in debug mode',
    );
  });
}
