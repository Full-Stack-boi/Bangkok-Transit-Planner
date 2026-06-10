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
    return _mockStations.where((s) =>
      s.nameEn.toLowerCase().contains(query.toLowerCase()) ||
      s.nameTh.toLowerCase().contains(query.toLowerCase()) ||
      s.code.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  @override
  Station? getStation(String id) {
    for (final s in _mockStations) {
      if (s.id == id) return s;
    }
    return null;
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

      // 3. ตรวจสอบหน้าจอเริ่มต้น (Assert): ตรวจพบหัวข้อแอป 'BKK Transit' บนหน้าจอค้นหา (หน้าแรก)
      expect(find.text('BKK Transit'), findsOneWidget);
      
      // ตรวจสอบว่ามี NavigationBar อยู่บนหน้าจอจริง
      expect(find.byType(NavigationBar), findsOneWidget);

      // ค้นหาและตรวจสอบว่ามีแท็บนำทางครบทั้ง 4 แท็บ (ค้นหาเส้นทาง, แผนที่, รายการโปรด, ตั้งค่า) ใน NavigationBar
      // อิงตามคำแปลภาษาไทยเริ่มต้น
      final navBar = find.byType(NavigationBar);
      expect(find.descendant(of: navBar, matching: find.text('ค้นหาเส้นทาง')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('แผนที่รถไฟฟ้า')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('รายการโปรด')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('ตั้งค่า')), findsOneWidget);

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
  });
}
