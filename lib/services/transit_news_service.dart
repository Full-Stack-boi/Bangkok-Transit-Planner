import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:bkk_transit_planner/core/network/http_client_factory.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

class TransitLineStatus {
  final String lineId;
  final String lineNameTh;
  final String lineNameEn;
  final String statusTh;
  final String statusEn;
  final bool isNormal;
  final String? matchedNewsTitle;

  const TransitLineStatus({
    required this.lineId,
    required this.lineNameTh,
    required this.lineNameEn,
    required this.statusTh,
    required this.statusEn,
    this.isNormal = true,
    this.matchedNewsTitle,
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
  final String? link;

  const TransitNewsArticle({
    required this.id,
    required this.titleTh,
    required this.titleEn,
    required this.bodyTh,
    required this.bodyEn,
    required this.date,
    required this.lineId,
    this.link,
  });
}

class TransitNewsService {
  final http.Client _client;

  TransitNewsService([http.Client? client]) : _client = client ?? http.Client();

  // Use Vercel Serverless Function proxy on Web to bypass CORS.
  // For other platforms (Android/iOS), use the direct DRT feed URL.
  final String _feedUrl = () {
    const envUrl = String.fromEnvironment('DRT_FEED_URL');
    if (kIsWeb) {
      // Direct RSS requests to external Department of Rail Transport website are blocked by browser CORS.
      // Force local Vercel serverless proxy if the URL is empty or direct.
      if (envUrl.isEmpty || envUrl.contains('drt.go.th')) {
        return '/api/drt-feed';
      }
      return envUrl;
    }
    return envUrl.isNotEmpty ? envUrl : 'https://www.drt.go.th/feed';
  }();

  Future<List<TransitNewsArticle>> fetchDrtNews() async {
    try {
      final url = Uri.parse(_feedUrl);
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return _parseDrtRss(response.body);
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Error fetching DRT news: $e', error: e);
      if (kDebugMode) {
        // Fallback to official mock announcements in debug mode only
        return _getMockDrtArticles()
            .where((art) => _isCommuterRelevant(art.titleTh, art.bodyTh))
            .toList();
      }
      rethrow;
    }
  }

  /// Check if the announcement is actually relevant to daily commuters
  bool _isCommuterRelevant(String title, String desc) {
    final text = '$title $desc'.toLowerCase();

    // 1. Blacklist administrative, procurement, recruitment, internal events
    final blacklist = [
      'จัดซื้อจัดจ้าง',
      'ประกวดราคา',
      'ราคากลาง',
      'ผู้ชนะการเสนอราคา',
      'ผู้ชนะ',
      'เสนอราคา',
      'จัดซื้อ',
      'จัดจ้าง',
      'ร่าง tor',
      'ร่าง ocr',
      ' tor ',
      'รับสมัคร',
      'สมัครงาน',
      'สรรหา',
      'จ้างงาน',
      'พนักงานราชการ',
      'อัตราว่าง',
      'ขึ้นบัญชี',
      'สอบคัดเลือก',
      'รับฟังความคิดเห็น',
      'วารสาร',
      'จดหมายข่าว',
      'newsletter',
      'e-book',
      'สัมมนา',
      'อบรม',
      'การเข้าพบ',
      'แสดงความยินดี',
      'ร่วมยินดี',
      'ลงนาม',
      'mou',
      'm.o.u.',
      'การลงนาม',
      'ต้อนรับ',
      'แสดงความเสียใจ',
      'ทำบุญ',
      'บริจาค',
      'กีฬา',
      ' ประชุม ',
      'ประชุมหารือ',
      'หารือ',
      'ดูงาน',
      'ศึกษาดูงาน',
      'สวดมนต์',
      'บำเพ็ญ',
      'อวยพร',
      'สวัสดีปีใหม่',
      'วันสงกรานต์',
      'ขอบคุณ',
      'การเปิดรับ',
      'เชิญชวน',
    ];

    for (final word in blacklist) {
      if (text.contains(word)) {
        return false;
      }
    }

    // 2. Requires at least one commuter keyword OR transit brand keyword to be shown
    final commuterKeywords = [
      'ขัดข้อง',
      'ล่าช้า',
      'งดให้บริการ',
      'ปิดสถานี',
      'ปรับเวลา',
      'เปิดให้บริการ',
      'ทดลองให้บริการ',
      'ฟรี',
      'ค่าโดยสาร',
      'บัตร',
      'ทางเชื่อม',
      'ทางเดินรถ',
      'ขบวนรถ',
      'ชานชาลา',
      'ขยายเวลา',
      'รถไฟฟ้า',
      'bts',
      'mrt',
      'arl',
      'สายสี',
      'สถานี',
      'แอร์พอร์ตลิงก์',
    ];

    for (final word in commuterKeywords) {
      if (text.contains(word)) {
        return true;
      }
    }

    return false;
  }

  /// Parse DRT RSS XML
  List<TransitNewsArticle> _parseDrtRss(String xmlBody) {
    final articles = <TransitNewsArticle>[];
    final items = xmlBody.split('<item>');
    if (items.length <= 1) return articles;

    // Load up to 8 announcement items
    for (int i = 1; i < items.length && i <= 8; i++) {
      final item = items[i].split('</item>')[0];

      // Extract title
      final titleMatch = RegExp(
        r'<title>(.*?)<\/title>',
        dotAll: true,
      ).firstMatch(item);
      var title = titleMatch != null ? titleMatch.group(1) ?? '' : '';
      title = _cleanXmlString(title);

      // Extract link
      final linkMatch = RegExp(
        r'<link>(.*?)<\/link>',
        dotAll: true,
      ).firstMatch(item);
      final link = linkMatch != null ? linkMatch.group(1) ?? '' : '';

      // Extract pubDate
      final dateMatch = RegExp(
        r'<pubDate>(.*?)<\/pubDate>',
        dotAll: true,
      ).firstMatch(item);
      final dateStr = dateMatch != null ? dateMatch.group(1) ?? '' : '';
      final pubDate = _parseRssDate(dateStr);

      // Extract description
      final descMatch = RegExp(
        r'<description>(.*?)<\/description>',
        dotAll: true,
      ).firstMatch(item);
      var desc = descMatch != null ? descMatch.group(1) ?? '' : '';
      desc = _cleanXmlString(desc);
      desc = desc.replaceAll(RegExp(r'<[^>]*>'), '');
      desc = desc.replaceAll('&#8230;', '...');
      if (desc.isEmpty) {
        desc = title;
      }

      final lineId = _detectLineId('$title $desc');

      if (_isCommuterRelevant(title, desc)) {
        articles.add(
          TransitNewsArticle(
            id: 'drt_$i',
            titleTh: title,
            titleEn: '', // DRT website is mainly Thai
            bodyTh: desc,
            bodyEn: '',
            date: pubDate,
            lineId: lineId,
            link: link.isNotEmpty ? link.trim() : null,
          ),
        );
      }
    }
    return articles;
  }

  DateTime _parseRssDate(String dateStr) {
    try {
      final cleaned = dateStr.trim().replaceFirst(
        RegExp(r'^[A-Za-z]+,\s*'),
        '',
      );
      final parts = cleaned.split(' ');
      if (parts.length >= 4) {
        final day = parts[0].padLeft(2, '0');
        final monthStr = parts[1];
        final year = parts[2];
        final time = parts[3];

        final months = {
          'Jan': '01',
          'Feb': '02',
          'Mar': '03',
          'Apr': '04',
          'May': '05',
          'Jun': '06',
          'Jul': '07',
          'Aug': '08',
          'Sep': '09',
          'Oct': '10',
          'Nov': '11',
          'Dec': '12',
        };

        final month = months[monthStr] ?? '01';
        final isoStr = '$year-$month-${day}T${time}Z';
        return DateTime.parse(isoStr).toLocal();
      }
      final cleanedDate = dateStr
          .replaceFirst(RegExp(r'^[A-Za-z]+,\s*'), '')
          .replaceFirst(RegExp(r'\s+[A-Z]+$'), 'Z');
      return DateTime.parse(cleanedDate).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  String _cleanXmlString(String input) {
    var str = input.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '').trim();
    str = str
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
    return str;
  }

  String _detectLineId(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('bts') ||
        lower.contains('sukhumvit') ||
        lower.contains('สุขุมวิท')) {
      return 'BTS_SUKHUMVIT';
    } else if (lower.contains('silom') || lower.contains('สีลม')) {
      return 'BTS_SILOM';
    } else if (lower.contains('mrt blue') || lower.contains('สีน้ำเงิน')) {
      return 'MRT_BLUE';
    } else if (lower.contains('mrt yellow') || lower.contains('สีเหลือง')) {
      return 'MRT_YELLOW';
    } else if (lower.contains('mrt pink') || lower.contains('สีชมพู')) {
      return 'MRT_PINK';
    } else if (lower.contains('mrt purple') || lower.contains('สีม่วง')) {
      return 'MRT_PURPLE';
    } else if (lower.contains('airport rail') ||
        lower.contains('arl') ||
        lower.contains('แอร์พอร์ต')) {
      return 'ARL';
    } else if (lower.contains('srt') || lower.contains('สายสีแดง')) {
      return 'SRT_RED_NORTH';
    }
    return 'GENERAL';
  }

  List<TransitNewsArticle> _getMockDrtArticles() {
    return [
      TransitNewsArticle(
        id: 'mock_drt_1',
        titleTh:
            'กรมรางประสาน MRT ขยายเวลาเปิดให้บริการรถไฟฟ้าสายสีน้ำเงินคืนปีใหม่ถึงตี 2',
        titleEn:
            'DRT collaborates with MRT to extend Blue Line service hours until 2 AM on New Year\'s Eve',
        bodyTh:
            'กรมการขนส่งทางรางร่วมกับ รฟม. และ BEM ประกาศขยายเวลาเปิดให้บริการรถไฟฟ้ามหานคร สายเฉลิมรัชมงคล (MRT สายสีน้ำเงิน) และสายฉลองรัชธรรม (MRT สายสีม่วง) ในคืนวันที่ 31 ธันวาคม 2569 จนถึงเวลา 02.00 น. ของวันที่ 1 มกราคม 2570 เพื่ออำนวยความสะดวกในการเดินทางเคาท์ดาวน์แก่ประชาชนอย่างปลอดภัย',
        bodyEn:
            'Department of Rail Transport in partnership with MRTA and BEM announces extended services for MRT Blue and Purple lines on Dec 31st until 2 AM to facilitate safe countdown travel.',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        lineId: 'MRT_BLUE',
      ),
      TransitNewsArticle(
        id: 'mock_drt_2',
        titleTh:
            'ประกาศปรับความถี่ขบวนรถไฟฟ้าสายสีแดงเข้ม ช่วงเร่งด่วนเช้า-เย็น เพื่อลดความหนาแน่นบนชานชาลา',
        titleEn:
            'SRT Red Line updates peak-hour train frequency to reduce platform crowding',
        bodyTh:
            'กรมการขนส่งทางรางประสาน รฟท. และบริษัท รถไฟฟ้า ร.ฟ.ท. จำกัด ปรับเพิ่มความถี่และปรับเวลาการเดินรถไฟชานเมืองสายสีแดง (สายสีแดงเข้ม ช่วงบางซื่อ-รังสิต) ในช่วงเวลาเร่งด่วนเช้า 07.00 - 09.00 น. และเร่งด่วนเย็น 17.00 - 19.30 น. เป็นทุกๆ 8 นาที เพื่อช่วยลดปัญหาผู้โดยสารพักคอยสะสมบนชานชาลา',
        bodyEn:
            'DRT coordinates frequency adjustment for SRT Red Line (Bang Sue - Rangsit) during morning (7-9 AM) and evening (5-7:30 PM) peak hours to 8-minute headways to minimize passenger waiting time.',
        date: DateTime.now().subtract(const Duration(days: 1)),
        lineId: 'SRT_RED_NORTH',
      ),
      TransitNewsArticle(
        id: 'mock_drt_3',
        titleTh:
            'กรมการขนส่งทางรางแจ้ง ฟรีค่าโดยสารรถไฟฟ้าแอร์พอร์ต เรล ลิงก์ และสายสีแดง สำหรับเด็กในวันเด็กแห่งชาติ',
        titleEn:
            'Free rides on Airport Rail Link and SRT Red Line for kids on National Children\'s Day',
        bodyTh:
            'กรมการขนส่งทางรางแถลงความร่วมมือ มอบของขวัญวันเด็กแห่งชาติประจำปี 2569 เปิดให้เด็กที่มีอายุไม่เกิน 14 ปี และมีความสูงไม่เกิน 140 ซม. สามารถโดยสารรถไฟฟ้าแอร์พอร์ต เรล ลิงก์ และรถไฟชานเมืองสายสีแดง ฟรีตลอดระยะเวลาให้บริการ ตั้งแต่เวลา 06.00 - 24.00 น.',
        bodyEn:
            'DRT announces free travel gift for children under 14 years old (height not exceeding 140cm) on Airport Rail Link and SRT Red Line during operating hours on Children\'s Day.',
        date: DateTime.now().subtract(const Duration(days: 2)),
        lineId: 'ARL',
      ),
      TransitNewsArticle(
        id: 'mock_drt_4',
        titleTh: 'สรุปผลการจัดซื้อจัดจ้างประจำเดือนมิถุนายน 2569',
        titleEn: '',
        bodyTh:
            'สรุปผลการจัดซื้อจัดจ้างประจำเดือนมิถุนายน 2569 ของกรมการขนส่งทางราง กระทรวงคมนาคม ประกาศรายงานเพื่อความโปร่งใสประจำปีงบประมาณ (จะถูกกรองออก)',
        bodyEn: '',
        date: DateTime.now().subtract(const Duration(days: 3)),
        lineId: 'GENERAL',
      ),
      TransitNewsArticle(
        id: 'mock_drt_5',
        titleTh:
            'ประกาศกรมการขนส่งทางราง เรื่อง รับสมัครบุคคลเพื่อเลือกสรรเป็นพนักงานราชการทั่วไป',
        titleEn: '',
        bodyTh:
            'กรมการขนส่งทางรางประกาศรับสมัครงานราชการทั่วไปเพื่อบรรจุแต่งตั้งบุคลากรปฏิบัติงานสนับสนุนระบบคมนาคมและนโยบายขนส่งระบบราง (จะถูกกรองออก)',
        bodyEn: '',
        date: DateTime.now().subtract(const Duration(days: 4)),
        lineId: 'GENERAL',
      ),
    ];
  }
}

final transitNewsServiceProvider = Provider(
  (ref) => TransitNewsService(createHttpClient()),
);
