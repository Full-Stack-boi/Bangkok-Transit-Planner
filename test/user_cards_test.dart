import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/models/transit_enums.dart';
import 'package:bkk_transit_planner/providers/user_cards_provider.dart';

void main() {
  group('TransitEnums & UserCards Tests', () {
    test('TransitCardType fromJson & toJson handles legacy and standard values', () {
      expect(TransitCardType.fromJson('standard'), equals(TransitCardType.standard));
      expect(TransitCardType.fromJson('student'), equals(TransitCardType.student));
      expect(TransitCardType.fromJson('senior'), equals(TransitCardType.senior));
      expect(TransitCardType.fromJson('trip_package'), equals(TransitCardType.tripPackage));
      expect(TransitCardType.fromJson('trippackage'), equals(TransitCardType.tripPackage));
      expect(TransitCardType.fromJson(null), equals(TransitCardType.standard));
      expect(TransitCardType.fromJson('unknown_value'), equals(TransitCardType.standard));

      expect(TransitCardType.standard.toJson(), equals('standard'));
      expect(TransitCardType.student.toJson(), equals('student'));
      expect(TransitCardType.senior.toJson(), equals('senior'));
      expect(TransitCardType.tripPackage.toJson(), equals('trip_package'));
    });

    test('TransitNetwork fromLineId maps lines to correct ticketing networks', () {
      // Rabbit Card network
      expect(TransitNetwork.fromLineId('BTS_SUKHUMVIT'), equals(TransitNetwork.bts));
      expect(TransitNetwork.fromLineId('BTS_SILOM'), equals(TransitNetwork.bts));
      expect(TransitNetwork.fromLineId('BTS_GOLD'), equals(TransitNetwork.bts));
      expect(TransitNetwork.fromLineId('MRT_YELLOW'), equals(TransitNetwork.bts));
      expect(TransitNetwork.fromLineId('MRT_PINK'), equals(TransitNetwork.bts));
      expect(TransitNetwork.fromLineId('MRT_PINK_BRANCH'), equals(TransitNetwork.bts));

      // BEM MRT Card network
      expect(TransitNetwork.fromLineId('MRT_BLUE'), equals(TransitNetwork.mrt));
      expect(TransitNetwork.fromLineId('MRT_PURPLE'), equals(TransitNetwork.mrt));

      // Airport Rail Link
      expect(TransitNetwork.fromLineId('ARL'), equals(TransitNetwork.arl));

      // SRT Red Lines
      expect(TransitNetwork.fromLineId('SRT_RED_NORTH'), equals(TransitNetwork.srt));
      expect(TransitNetwork.fromLineId('SRT_RED_WEST'), equals(TransitNetwork.srt));

      // Unknown
      expect(TransitNetwork.fromLineId('WALK'), isNull);
    });

    test('UserCardsState forNetwork returns proper card type per network', () {
      const state = UserCardsState(
        btsCardType: TransitCardType.student,
        mrtCardType: TransitCardType.senior,
        arlCardType: TransitCardType.standard,
        srtCardType: TransitCardType.student,
      );

      expect(state.forNetwork(TransitNetwork.bts), equals(TransitCardType.student));
      expect(state.forNetwork(TransitNetwork.mrt), equals(TransitCardType.senior));
      expect(state.forNetwork(TransitNetwork.arl), equals(TransitCardType.standard));
      expect(state.forNetwork(TransitNetwork.srt), equals(TransitCardType.student));
    });
  });
}
