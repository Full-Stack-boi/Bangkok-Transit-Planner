import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bkk_transit_planner/app.dart';
import 'package:bkk_transit_planner/providers/providers.dart';
import 'package:bkk_transit_planner/models/station.dart';
import 'package:bkk_transit_planner/models/line.dart';
import 'package:bkk_transit_planner/services/dijkstra_planner.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/services/location_service.dart';
import 'package:bkk_transit_planner/services/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bkk_transit_planner/features/map/widgets/route_result_banner.dart';
import 'package:bkk_transit_planner/features/route_result/route_result_sheet.dart';
import 'package:bkk_transit_planner/features/search/search_view_model.dart';
import 'package:bkk_transit_planner/features/map/map_screen.dart';

// ─── หัวข้อการเรียนรู้: Widget Test คืออะไร? ───
// Widget Test คือการทดสอบองค์ประกอบส่วนติดต่อผู้ใช้ (UI Components/Widgets) ในสภาพแวดล้อมจำลอง
// ช่วยให้นักพัฒนาสามารถจำลองพฤติกรรมผู้ใช้ เช่น การคลิกปุ่ม, การพิมพ์ข้อความ, การปัดหน้าจอ
// และยืนยันได้ว่าหน้าจอ UI แสดงผลได้ถูกต้องตามที่ควรจะเป็น โดยไม่จำเป็นต้องเปิด Emulator/เครื่องจริง

class MockTransitRepository extends TransitRepository {
  final List<Station> _mockStations = [
    const Station(
      id: 'BTS_A',
      code: 'N1',
      nameTh: 'สถานีเอ',
      nameEn: 'Station A',
      lat: 13.75,
      lng: 100.52,
      lineId: 'BTS_SUKHUMVIT',
      interchange: [],
    ),
    const Station(
      id: 'BTS_B',
      code: 'N2',
      nameTh: 'สถานีบี',
      nameEn: 'Station B',
      lat: 13.76,
      lng: 100.53,
      lineId: 'BTS_SUKHUMVIT',
      interchange: [],
    ),
  ];

  @override
  bool get isInitialized => true;

  @override
  List<Station> get stations => _mockStations;

  @override
  List<TransitLine> get lines => [
    const TransitLine(
      id: 'BTS_SUKHUMVIT',
      nameTh: 'สายสุขุมวิท',
      nameEn: 'Sukhumvit Line',
      operator: 'BTS',
      colorHex: '#00FF00',
      stationIds: ['BTS_A', 'BTS_B'],
      bound0Label: 'ไปคูคต',
      bound1Label: 'ไปเคหะฯ',
      isLoop: false,
      peakIntervalMin: 3,
      offPeakIntervalMin: 6,
    )
  ];

  @override
  TransitGraph get graph {
    final g = TransitGraph();
    for (final s in _mockStations) {
      g.addStation(s);
    }
    g.addEdge('BTS_A', 'BTS_B', 'BTS_SUKHUMVIT', weight: 2.0);
    return g;
  }

  @override
  Future<void> initialize() async {}

  @override
  List<Station> searchStations(String query) {
    if (query.isEmpty) return _mockStations;
    final q = query.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return _mockStations.where((s) {
      final normalizedTh = s.nameTh.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final normalizedEn = s.nameEn.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final normalizedCode = s.code.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      return normalizedTh.contains(q) ||
             normalizedEn.contains(q) ||
             normalizedCode.contains(q);
    }).toList();
  }

  @override
  Station? getStation(String id) {
    for (final s in _mockStations) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  TransitLine? getLine(String lineId) {
    return lines.firstWhere((l) => l.id == lineId);
  }

  @override
  DijkstraResult? findRoute(String fromId, String toId) {
    return graph.findShortestPath(fromId, toId);
  }
}

class MockLocationService extends LocationService {
  @override
  Future<bool> isLocationPermissionGranted() async => true;

  @override
  Future<bool> requestLocationPermission() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<Position?> getCurrentPosition() async => null;
}

class MockNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {}
}

void main() {
  setUp(() {
    // จำลอง SharedPreferences สำหรับรันเทสต์ เพื่อไม่ให้พึ่งพาระบบไฟล์ของแพลตฟอร์มจริง
    SharedPreferences.setMockInitialValues({});
  });

  group('BkkTransitApp Widget Tests', () {
    testWidgets('Should render home screen with bottom navigation and switch tabs', (WidgetTester tester) async {
      // 1. เตรียมสภาพแวดล้อม (Arrange): กำหนด ProviderScope และ Override mock providers
      final container = ProviderScope(
        overrides: [
          transitInitProvider.overrideWith((ref) => Future.value(null)),
          transitRepositoryProvider.overrideWithValue(MockTransitRepository()),
          locationServiceProvider.overrideWithValue(MockLocationService()),
          notificationServiceProvider.overrideWithValue(MockNotificationService()),
        ],
        child: const BkkTransitApp(),
      );

      // 2. โหลดหน้าจอเสมือนจริง (Act): เรียก pumpWidget() เพื่อสร้าง widget tree ขึ้นมาทดสอบ
      await tester.pumpWidget(container);
      
      // รอให้การโหลด asynchronous ต่างๆ หรืออนิเมชั่นเริ่มต้นเสร็จสิ้น
      await tester.pumpAndSettle();

      // 3. ตรวจสอบหน้าจอเริ่มต้น (Assert): ตอนนี้เปิดที่หน้า Map (fullscreen, ไม่มี AppBar title)
      // ตรวจสอบว่ามี NavigationBar อยู่บนหน้าจอจริง
      expect(find.byType(NavigationBar), findsOneWidget);

      // ค้นหาและตรวจสอบว่ามีแท็บนำทางครบทั้ง 4 แท็บใน NavigationBar
      // อิงตามคำแปลภาษาไทยเริ่มต้น
      final navBar = find.byType(NavigationBar);
      expect(find.descendant(of: navBar, matching: find.text('บริการ')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('แผนที่รถไฟฟ้า')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('รายการโปรด')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('ตั้งค่า')), findsOneWidget);

      // ตรวจสอบว่า app เปิดที่หน้า Map (MapScreen widget ควรมีอยู่บนหน้าจอ)
      expect(find.byType(MapScreen), findsOneWidget);

      // 4. จำลองการคลิกเปลี่ยนแท็บไปยังแท็บ "ตั้งค่า" (Act)
      final settingsTab = find.descendant(of: navBar, matching: find.text('ตั้งค่า'));
      await tester.tap(settingsTab);
      
      // อัปเดต UI หลังจากมีการคลิกเพื่อแสดงหน้าต่างใหม่
      await tester.pumpAndSettle();

      // 5. ตรวจสอบว่าอยู่หน้าตั้งค่าจริงหรือไม่ (Assert)
      // ตรวจหาคำว่า "ธีม" หรือ "ภาษา" ที่จะโผล่เฉพาะในหน้าตั้งค่าเท่านั้น
      expect(find.text('ธีม'), findsOneWidget);
      expect(find.text('ภาษา'), findsOneWidget);
    });

    testWidgets('Should show route result banner on map screen and open detail sheet on tap', (WidgetTester tester) async {
      final repo = MockTransitRepository();
      final container = ProviderScope(
        overrides: [
          transitInitProvider.overrideWith((ref) => Future.value(null)),
          transitRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(MockLocationService()),
          notificationServiceProvider.overrideWithValue(MockNotificationService()),
        ],
        child: const BkkTransitApp(),
      );

      await tester.pumpWidget(container);
      await tester.pumpAndSettle();

      // Find the search view model and set origin & destination to calculate a route
      final element = tester.element(find.byType(BkkTransitApp));
      final ref = ProviderScope.containerOf(element);
      final searchVm = ref.read(searchViewModelProvider.notifier);
      final stationA = repo.getStation('BTS_A')!;
      final stationB = repo.getStation('BTS_B')!;

      searchVm.setOrigin(stationA);
      searchVm.setDestination(stationB);
      await tester.pumpAndSettle();

      // Switch to the map tab
      final navBar = find.byType(NavigationBar);
      final mapTab = find.descendant(of: navBar, matching: find.text('แผนที่รถไฟฟ้า'));
      await tester.tap(mapTab);
      await tester.pumpAndSettle();

      // Verify RouteResultBanner is displayed on MapScreen
      expect(find.byType(RouteResultBanner), findsOneWidget);

      // Verify that details chip info is shown (e.g. fare or minutes)
      expect(find.textContaining('นาที'), findsOneWidget);

      // Tap on RouteResultBanner
      await tester.tap(find.byType(RouteResultBanner));
      await tester.pumpAndSettle();

      // Verify RouteResultSheet bottom sheet is open
      expect(find.byType(RouteResultSheet), findsOneWidget);
    });

    testWidgets('Should save route and restore it correctly on tap', (WidgetTester tester) async {
      final repo = MockTransitRepository();
      final container = ProviderScope(
        overrides: [
          transitInitProvider.overrideWith((ref) => Future.value(null)),
          transitRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(MockLocationService()),
          notificationServiceProvider.overrideWithValue(MockNotificationService()),
        ],
        child: const BkkTransitApp(),
      );

      await tester.pumpWidget(container);
      await tester.pumpAndSettle();

      // Find the search view model and set origin & destination to calculate a route
      final element = tester.element(find.byType(BkkTransitApp));
      final ref = ProviderScope.containerOf(element);
      final searchVm = ref.read(searchViewModelProvider.notifier);
      final stationA = repo.getStation('BTS_A')!;
      final stationB = repo.getStation('BTS_B')!;

      searchVm.setOrigin(stationA);
      searchVm.setDestination(stationB);
      await tester.pumpAndSettle();

      // Switch to the map tab
      final navBar = find.byType(NavigationBar);
      final mapTab = find.descendant(of: navBar, matching: find.text('แผนที่รถไฟฟ้า'));
      await tester.tap(mapTab);
      await tester.pumpAndSettle();

      // Tap on RouteResultBanner to open bottom sheet
      await tester.tap(find.byType(RouteResultBanner));
      await tester.pumpAndSettle();

      // Tap the bookmark button
      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pumpAndSettle();

      // Enter custom route name in dialog
      await tester.enterText(find.byType(TextField), 'My Test Saved Route');
      await tester.pumpAndSettle();

      // Tap 'บันทึก' (Save) button in dialog
      await tester.tap(find.text('บันทึก'));
      await tester.pumpAndSettle();

      // Verify bottom sheet is still there (dialog closed)
      expect(find.byType(RouteResultSheet), findsOneWidget);

      // Close the bottom sheet by popping it
      Navigator.pop(tester.element(find.byType(RouteResultSheet)));
      await tester.pumpAndSettle();

      // Switch to Favorites tab
      ref.read(homeTabIndexProvider.notifier).setTab(2);
      await tester.pumpAndSettle();

      // Tap on Saved Routes tab inside Favorites screen
      final routesTab = find.descendant(of: find.byType(TabBar), matching: find.byIcon(Icons.route_rounded));
      await tester.tap(routesTab);
      await tester.pumpAndSettle();

      // Verify the saved route is listed
      expect(find.text('My Test Saved Route'), findsOneWidget);

      // Clear search to simulate starting fresh
      searchVm.clear();
      await tester.pumpAndSettle();

      // Tap on the saved route card
      await tester.tap(find.text('My Test Saved Route'));
      await tester.pumpAndSettle();

      // Should automatically switch back to the Map tab (index 1)
      expect(find.byType(MapScreen), findsOneWidget);

      // Verify that the route results banner is shown on Map screen
      expect(find.byType(RouteResultBanner), findsOneWidget);

      // Verify that the search viewModel has origin and destination active and route calculated
      final state = ref.read(searchViewModelProvider);
      expect(state.origin, isNotNull);
      expect(state.destination, isNotNull);
      expect(state.origin!.id, equals('BTS_A'));
      expect(state.destination!.id, equals('BTS_B'));
      expect(state.routeResult, isNotNull);
    });
  });
}
