import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/models/station.dart';
import 'package:bkk_transit_planner/services/dijkstra_planner.dart';

void main() {
  // หัวข้อการเรียนรู้: Unit Test คืออะไร?
  // Unit Test คือการทดสอบส่วนเล็กๆ ของโค้ด (เช่น ฟังก์ชัน หรือ คลาสเดี่ยวๆ)
  // โดยไม่มีการพึ่งพาระบบภายนอก (เช่น ฐานข้อมูล, หน้าจอ UI หรือการโหลด Asset ของอุปกรณ์จริง)
  // ทำให้ตรวจหาจุดบกพร่อง (Bug) ได้รวดเร็วและแม่นยำมาก

  // group() ใช้ในการจัดกลุ่มการทดสอบที่เกี่ยวข้องกันเข้าด้วยกันเพื่อความเป็นระเบียบ
  group('Transit Routing (Dijkstra Algorithm) Tests', () {
    late TransitGraph graph;

    // setUp() จะทำงานทุกครั้งก่อนรันแต่ละ test() ย่อย
    // เพื่อสร้างสถานะเริ่มต้น (Initial State) ที่สะอาดและพร้อมใช้งาน
    setUp(() {
      graph = TransitGraph();

      // สร้างสถานีจำลองสำหรับทดสอบ (Mock Stations)
      // Line 1: BTS Sukhumvit (Mock)
      graph.addStation(
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
      );

      graph.addStation(
        const Station(
          id: 'BTS_B', // จุดเชื่อมต่อ (Interchange Station)
          code: 'N2',
          nameTh: 'สถานีบี',
          nameEn: 'Station B',
          lat: 13.76,
          lng: 100.53,
          lineId: 'BTS_SUKHUMVIT',
          interchange: ['MRT_C'], // เชื่อมต่อไป MRT_C
        ),
      );

      // Line 2: MRT Blue Line (Mock)
      graph.addStation(
        const Station(
          id: 'MRT_C', // จุดเชื่อมต่อฝั่ง MRT
          code: 'BL01',
          nameTh: 'สถานีซี',
          nameEn: 'Station C',
          lat: 13.76,
          lng: 100.53,
          lineId: 'MRT_BLUE',
          interchange: ['BTS_B'], // เชื่อมต่อไป BTS_B
        ),
      );

      graph.addStation(
        const Station(
          id: 'MRT_D',
          code: 'BL02',
          nameTh: 'สถานีดี',
          nameEn: 'Station D',
          lat: 13.77,
          lng: 100.54,
          lineId: 'MRT_BLUE',
          interchange: [],
        ),
      );

      // เพิ่มเส้นทางเดินรถแบบระบุระยะเวลาที่ใช้ (Edges)
      // เดินรถระหว่าง A <-> B ใช้เวลา 2 นาที
      graph.addEdge('BTS_A', 'BTS_B', 'BTS_SUKHUMVIT', weight: 2.0);

      // เดินรถระหว่าง C <-> D ใช้เวลา 3 นาที
      graph.addEdge('MRT_C', 'MRT_D', 'MRT_BLUE', weight: 3.0);

      // การเชื่อมต่อระหว่าง B <-> C ด้วยการเดินเปลี่ยนชานชาลา (Transfer) ใช้เวลา 5 นาที
      graph.addTransferEdge('BTS_B', 'MRT_C', walkingMinutes: 5.0);
    });

    // test() ใช้ในการระบุเคสทดสอบเดี่ยวๆ พร้อมคำอธิบายจุดประสงค์การทดสอบ
    test('Should find direct route on the same line without transfers', () {
      // 1. ลงมือทำ (Act): เรียกคำนวณเส้นทางจาก A ไป B
      final result = graph.findShortestPath('BTS_A', 'BTS_B');

      // 2. ตรวจสอบผลลัพธ์ (Assert/Expect): ใช้ฟังก์ชัน expect() เทียบค่าจริงกับค่าที่คาดหวัง
      expect(result, isNotNull); // ผลลัพธ์ต้องไม่ใช่ null
      expect(result!.stationCount, equals(2)); // ต้องผ่านทั้งหมด 2 สถานี
      expect(
        result.transferCount,
        equals(0),
      ); // ต้องไม่มีการเปลี่ยนสาย (0 transfer)
      expect(
        result.totalWeight,
        equals(2.0),
      ); // เวลาเดินทางรวมต้องเป็น 2.0 นาที
    });

    test(
      'Should calculate correct route and transfer details between different lines',
      () {
        // 1. ลงมือทำ (Act): เรียกคำนวณเส้นทางจาก A ไป D (ข้ามสายผ่านจุดเปลี่ยนเส้นทาง)
        final offPeakTime = DateTime(2026, 1, 1, 12, 0);
        final result = graph.findShortestPath(
          'BTS_A',
          'MRT_D',
          time: offPeakTime,
        );

        // 2. ตรวจสอบผลลัพธ์ (Assert)
        expect(result, isNotNull);
        expect(
          result!.stationCount,
          equals(4),
        ); // เส้นทางที่สั้นที่สุดต้องผ่าน A -> B -> C -> D (4 ขั้นตอน)
        expect(
          result.transferCount,
          equals(1),
        ); // ต้องมีการเปลี่ยนสาย 1 ครั้ง (จาก BTS ไป MRT)

        // เวลาเดินทางรวม: A->B (2.0) + เดินเปลี่ยนสาย B->C (5.0) + รอรถ (5.0) + C->D (3.0) = 15.0 นาที
        expect(result.totalWeight, equals(15.0));

        // ตรวจสอบโครงสร้างลำดับสถานีจริง
        expect(result.path[0].stationId, equals('BTS_A'));
        expect(result.path[1].stationId, equals('BTS_B'));
        expect(result.path[2].stationId, equals('MRT_C'));
        expect(result.path[3].stationId, equals('MRT_D'));
      },
    );

    test(
      'Should return weight of 0 and same station when origin and destination are identical',
      () {
        final result = graph.findShortestPath('BTS_A', 'BTS_A');

        expect(result, isNotNull);
        expect(result!.stationCount, equals(1));
        expect(result.totalWeight, equals(0.0));
        expect(result.path.first.stationId, equals('BTS_A'));
      },
    );

    test(
      'Should return null if there is no possible path between stations',
      () {
        // สร้างสถานีแยกเดี่ยว (Orphan Station) ที่ไม่มีทางรถไฟเชื่อมเข้าหา
        graph.addStation(
          const Station(
            id: 'ORPHAN',
            code: 'OP1',
            nameTh: 'สถานีโดดเดี่ยว',
            nameEn: 'Orphan Station',
            lat: 13.99,
            lng: 100.99,
            lineId: 'UNKNOWN_LINE',
            interchange: [],
          ),
        );

        final result = graph.findShortestPath('BTS_A', 'ORPHAN');

        // ต้องได้ค่ากลับคืนมาเป็น null เพราะไม่มีเส้นทางเชื่อมโยงไปถึงได้
        expect(result, isNull);
      },
    );
  });
}
