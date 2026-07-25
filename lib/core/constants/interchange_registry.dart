import 'transit_constants.dart';

enum TransferType { skywalk, exit, platformLevel, walk }

class InterchangeRecord {
  final String stationA;
  final String stationB;
  final TransferType type;
  final int defaultWalkMinutes;
  final Map<String, String>? exitByStation;
  final Map<String, String>? exitByStationEn;
  final String? levelInfoTh;
  final String? levelInfoEn;

  const InterchangeRecord({
    required this.stationA,
    required this.stationB,
    required this.type,
    this.defaultWalkMinutes = 2,
    this.exitByStation,
    this.exitByStationEn,
    this.levelInfoTh,
    this.levelInfoEn,
  });

  bool matches(String fromId, String toId) {
    return (stationA == fromId && stationB == toId) ||
        (stationA == toId && stationB == fromId);
  }

  String getExitInfo(String fromId, bool isEnglish) {
    if (exitByStation == null) return '';
    if (isEnglish &&
        exitByStationEn != null &&
        exitByStationEn!.containsKey(fromId)) {
      return exitByStationEn![fromId]!;
    }
    return exitByStation![fromId] ?? '';
  }

  String getLevelInfo(bool isEnglish) {
    if (isEnglish) return levelInfoEn ?? levelInfoTh ?? '';
    return levelInfoTh ?? levelInfoEn ?? '';
  }
}

class InterchangeRegistry {
  static final List<InterchangeRecord> _records = [
    // Makkasan (ARL) <-> Phetchaburi (MRT)
    const InterchangeRecord(
      stationA: TransitConstants.kStationArlMakkasanA6,
      stationB: TransitConstants.kStationMrtPhetchaburiBl21,
      type: TransferType.skywalk,
      defaultWalkMinutes: 3,
    ),
    // Sukhumvit (MRT) <-> Asok (BTS)
    const InterchangeRecord(
      stationA: TransitConstants.kStationMrtAsokBl22,
      stationB: TransitConstants.kStationBtsSukhumvitE4,
      type: TransferType.exit,
      defaultWalkMinutes: 2,
      exitByStation: {
        TransitConstants.kStationMrtAsokBl22: '3',
        TransitConstants.kStationBtsSukhumvitE4: '3',
      },
    ),
    // Si Lom (MRT) <-> Sala Daeng (BTS)
    const InterchangeRecord(
      stationA: TransitConstants.kStationMrtSilomBl26,
      stationB: TransitConstants.kStationBtsSaladaengS2,
      type: TransferType.exit,
      defaultWalkMinutes: 3,
      exitByStation: {
        TransitConstants.kStationMrtSilomBl26: '2',
        TransitConstants.kStationBtsSaladaengS2: '4',
      },
    ),
    // Chatuchak Park (MRT) <-> Mo Chit (BTS)
    const InterchangeRecord(
      stationA: TransitConstants.kStationMrtChatuchakBl13,
      stationB: TransitConstants.kStationBtsMochitN8,
      type: TransferType.exit,
      defaultWalkMinutes: 2,
      exitByStation: {
        TransitConstants.kStationMrtChatuchakBl13: '1 หรือ 2',
        TransitConstants.kStationBtsMochitN8: '1 หรือ 3',
      },
      exitByStationEn: {
        TransitConstants.kStationMrtChatuchakBl13: '1 or 2',
        TransitConstants.kStationBtsMochitN8: '1 or 3',
      },
    ),
    // Lat Phrao (Blue <-> Yellow)
    const InterchangeRecord(
      stationA: TransitConstants.kStationMrtLatphraoBl15,
      stationB: TransitConstants.kStationMrtLatphraoYl01,
      type: TransferType.platformLevel,
      defaultWalkMinutes: 2,
      levelInfoTh: 'ยกระดับ/ใต้ดิน',
      levelInfoEn: 'Elevated/Underground',
    ),
    // Phaya Thai (BTS <-> ARL)
    const InterchangeRecord(
      stationA: TransitConstants.kStationBtsPhayathaiN2,
      stationB: TransitConstants.kStationArlPhayathaiA8,
      type: TransferType.skywalk,
      defaultWalkMinutes: 2,
    ),
    // Samrong (BTS <-> Yellow)
    const InterchangeRecord(
      stationA: TransitConstants.kStationBtsSamrongE15,
      stationB: TransitConstants.kStationMrtSamrongYl23,
      type: TransferType.skywalk,
      defaultWalkMinutes: 2,
    ),
    // Hua Mak (ARL <-> Yellow)
    const InterchangeRecord(
      stationA: TransitConstants.kStationArlHuamakA4,
      stationB: TransitConstants.kStationMrtHuamakYl11,
      type: TransferType.skywalk,
      defaultWalkMinutes: 2,
    ),
  ];

  static InterchangeRecord? lookup(String fromId, String toId) {
    for (final record in _records) {
      if (record.matches(fromId, toId)) {
        return record;
      }
    }
    return null;
  }
}
