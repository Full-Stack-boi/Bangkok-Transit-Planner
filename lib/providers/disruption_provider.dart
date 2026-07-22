import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transit_disruption.dart';

class DisruptionState {
  final bool isMockActive;
  final List<TransitDisruption> disruptions;

  const DisruptionState({
    this.isMockActive = false,
    this.disruptions = const [],
  });

  DisruptionState copyWith({
    bool? isMockActive,
    List<TransitDisruption>? disruptions,
  }) {
    return DisruptionState(
      isMockActive: isMockActive ?? this.isMockActive,
      disruptions: disruptions ?? this.disruptions,
    );
  }

  /// Get disruptions for a specific line ID
  List<TransitDisruption> getDisruptionsForLine(String lineId) {
    return disruptions.where((d) => d.lineId == lineId).toList();
  }

  /// Check if a specific station ID is currently disrupted
  bool isStationDisrupted(String stationId) {
    return disruptions.any((d) => d.affectedStationIds.contains(stationId));
  }

  /// Check if a station pair / segment is disrupted
  bool isSegmentDisrupted(String fromId, String toId) {
    return disruptions.any(
      (d) =>
          d.affectedSegmentIds.contains('$fromId->$toId') ||
          d.affectedSegmentIds.contains('$toId->$fromId'),
    );
  }

  /// Get disruption affecting a station, if any
  TransitDisruption? getDisruptionForStation(String stationId) {
    for (final d in disruptions) {
      if (d.affectedStationIds.contains(stationId)) return d;
    }
    return null;
  }
}

class DisruptionNotifier extends Notifier<DisruptionState> {
  @override
  DisruptionState build() {
    return const DisruptionState();
  }

  /// Preset 1: Siam Station Delay (+15 mins)
  void applySiamDelayPreset() {
    final disruption = TransitDisruption(
      id: 'mock_siam_delay',
      lineId: 'BTS_SUKHUMVIT',
      severity: DisruptionSeverity.minorDelay,
      affectedStationIds: ['BTS_CEN', 'BTS_CEN_SILOM'],
      affectedSegmentIds: ['BTS_N1->BTS_CEN', 'BTS_CEN->BTS_E1'],
      titleTh: 'สัญญาณขัดข้องที่สถานีสยาม',
      titleEn: 'Signal Failure at Siam Station',
      descriptionTh:
          'ขบวนรถไฟฟ้าเคลื่อนที่ด้วยความเร็วจำกัด ล่าช้าประมาณ 15 นาที',
      descriptionEn: 'Trains operating at reduced speed with ~15 mins delay.',
      estimatedDelayMinutes: 15,
      alternativeAdviceTh: 'แนะนำให้เผื่อเวลาเดินทาง หรือใช้เส้นทางเลี่ยง',
      alternativeAdviceEn: 'Please allow extra time or use alternative routes.',
      reportedAt: DateTime.now(),
    );
    state = DisruptionState(isMockActive: true, disruptions: [disruption]);
  }

  /// Preset 2: Mo Chit -> Ha Yaek Lat Phrao Partial Closure
  void applyMoChitClosurePreset() {
    final disruption = TransitDisruption(
      id: 'mock_mochit_closure',
      lineId: 'BTS_SUKHUMVIT',
      severity: DisruptionSeverity.partialClosure,
      affectedStationIds: ['BTS_N8', 'BTS_N9'],
      affectedSegmentIds: ['BTS_N8->BTS_N9', 'BTS_N9->BTS_N8'],
      titleTh: 'ปิดให้บริการชั่วคราวช่วง หมอชิต ➔ ห้าแยกลาดพร้าว',
      titleEn: 'Temporary closure between Mo Chit ➔ Ha Yaek Lat Phrao',
      descriptionTh:
          'เกิดเหตุระบบไฟฟ้าขัดข้อง งดให้บริการช่วงหมอชิตถึงห้าแยกลาดพร้าว',
      descriptionEn:
          'Power disruption. Service suspended between Mo Chit and Ha Yaek Lat Phrao.',
      estimatedDelayMinutes: 30,
      alternativeAdviceTh:
          'แนะนำให้เปลี่ยนไปใช้ MRT สวนจตุจักร (BL13) ➔ ลาดพร้าว (BL15) แทน',
      alternativeAdviceEn:
          'Recommend transferring to MRT Chatuchak Park (BL13) ➔ Lat Phrao (BL15).',
      reportedAt: DateTime.now(),
    );
    state = DisruptionState(isMockActive: true, disruptions: [disruption]);
  }

  /// Preset 3: MRT Purple Line Full Closure
  void applyPurpleLineClosurePreset() {
    final disruption = TransitDisruption(
      id: 'mock_purple_closure',
      lineId: 'MRT_PURPLE',
      severity: DisruptionSeverity.fullClosure,
      affectedStationIds: List.generate(
        16,
        (i) => 'MRT_PP${(i + 1).toString().padLeft(2, '0')}',
      ),
      affectedSegmentIds: [],
      titleTh: 'ระงับการให้บริการ MRT สายสีม่วงชั่วคราวทั้งสาย',
      titleEn: 'MRT Purple Line temporary full suspension',
      descriptionTh: 'ระบบควบคุมการเดินรถขัดข้อง งดให้บริการทุกสถานีชั่วคราว',
      descriptionEn: 'Control system failure. All stations temporarily closed.',
      estimatedDelayMinutes: 60,
      alternativeAdviceTh: 'โปรดใช้บริการรถโดยสารขสมก. หรือระบบขนส่งทางเลือก',
      alternativeAdviceEn: 'Please use BMTA buses or alternative transit.',
      reportedAt: DateTime.now(),
    );
    state = DisruptionState(isMockActive: true, disruptions: [disruption]);
  }

  /// Set custom disruption
  void setCustomDisruption(TransitDisruption disruption) {
    state = DisruptionState(isMockActive: true, disruptions: [disruption]);
  }

  /// Clear all mock disruptions
  void clearDisruptions() {
    state = const DisruptionState(isMockActive: false, disruptions: []);
  }
}

final disruptionProvider =
    NotifierProvider<DisruptionNotifier, DisruptionState>(
      DisruptionNotifier.new,
    );
