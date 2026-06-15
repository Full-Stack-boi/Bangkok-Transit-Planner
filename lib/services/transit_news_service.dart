import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransitLineStatus {
  final String lineId;
  final String lineNameTh;
  final String lineNameEn;
  final String statusTh;
  final String statusEn;
  final bool isNormal;

  const TransitLineStatus({
    required this.lineId,
    required this.lineNameTh,
    required this.lineNameEn,
    required this.statusTh,
    required this.statusEn,
    this.isNormal = true,
  });
}

class TransitNewsArticle {
  final String id;
  final String titleTh;
  final String titleEn;
  final String bodyTh;
  final String bodyEn;
  final DateTime date;
  final String lineId;

  const TransitNewsArticle({
    required this.id,
    required this.titleTh,
    required this.titleEn,
    required this.bodyTh,
    required this.bodyEn,
    required this.date,
    required this.lineId,
  });
}

class TransitNewsService {
  List<TransitLineStatus> getLineStatuses() {
    return [
      const TransitLineStatus(
        lineId: 'BTS_SUKHUMVIT',
        lineNameTh: 'สายสุขุมวิท',
        lineNameEn: 'Sukhumvit Line',
        statusTh: 'ปกติ',
        statusEn: 'Normal',
      ),
      const TransitLineStatus(
        lineId: 'BTS_SILOM',
        lineNameTh: 'สายสีลม',
        lineNameEn: 'Silom Line',
        statusTh: 'ปกติ',
        statusEn: 'Normal',
      ),
      const TransitLineStatus(
        lineId: 'MRT_BLUE',
        lineNameTh: 'สายสีน้ำเงิน',
        lineNameEn: 'Blue Line',
        statusTh: 'ปกติ',
        statusEn: 'Normal',
      ),
      const TransitLineStatus(
        lineId: 'MRT_YELLOW',
        lineNameTh: 'สายสีเหลือง',
        lineNameEn: 'Yellow Line',
        statusTh: 'ปรับปรุงระบบ (ล่าช้า 10 นาที)',
        statusEn: 'Maintenance (10m delay)',
        isNormal: false,
      ),
      const TransitLineStatus(
        lineId: 'ARL',
        lineNameTh: 'แอร์พอร์ตลิงก์',
        lineNameEn: 'Airport Rail Link',
        statusTh: 'ปกติ',
        statusEn: 'Normal',
      ),
    ];
  }

  List<TransitNewsArticle> getNewsArticles() {
    return [
      TransitNewsArticle(
        id: '1',
        titleTh: 'MRT สายสีเหลืองปรับปรุงระบบชั่วคราว',
        titleEn: 'MRT Yellow Line Maintenance Alert',
        bodyTh: 'ปรับปรุงระบบไฟฟ้าส่งผลให้ล่าช้าประมาณ 10 นาที ขออภัยในความไม่สะดวก',
        bodyEn: 'Power maintenance causes 10-minute delays. We apologize.',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        lineId: 'MRT_YELLOW',
      ),
      TransitNewsArticle(
        id: '2',
        titleTh: 'BTS สำรวจความพึงพอใจการใช้ตั๋วร่วม',
        titleEn: 'BTS Commuter Satisfaction Survey',
        bodyTh: 'ขอเชิญผู้โดยสารร่วมทำแบบสอบถามเพื่อการปรับปรุงระบบในอนาคต',
        bodyEn: 'We invite passengers to complete our survey for future updates.',
        date: DateTime.now().subtract(const Duration(days: 1)),
        lineId: 'BTS_SUKHUMVIT',
      ),
    ];
  }
}

final transitNewsServiceProvider = Provider((ref) => TransitNewsService());
