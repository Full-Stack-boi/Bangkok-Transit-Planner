import 'base_localizations.dart';

class ThaiLocalizations implements BaseLocalizations {
  @override
  final common = ThaiCommon();
  @override
  final navigation = ThaiNavigation();
  @override
  final search = ThaiSearch();
  @override
  final favorites = ThaiFavorites();
  @override
  final routeResult = ThaiRouteResult();
  @override
  final errors = ThaiErrors();
  @override
  final directions = ThaiDirections();
  @override
  final transfers = ThaiTransfers();
  @override
  final proximity = ThaiProximity();
  @override
  final settings = ThaiSettings();
  @override
  final journey = ThaiJourney();
  @override
  final auth = ThaiAuth();
  @override
  final utility = ThaiUtility();
}

class ThaiCommon implements BaseCommon {
  @override
  String get appTitle => 'BKK Transit';
  @override
  String get cancelBtn => 'ยกเลิก';
  @override
  String get saveBtn => 'บันทึก';
  @override
  String get minutesUnit => 'นาที';
  @override
  String get secondsUnit => 'วินาที';
  @override
  String get currencyUnit => 'บาท';
  @override
  String get kmUnit => 'กม.';
  @override
  String get metersUnit => 'เมตร';
  @override
  String get total => 'รวม';
  @override
  String get laterBtn => 'ไว้ทีหลัง';
  @override
  String get errorOccurred => 'เกิดข้อผิดพลาด';
  @override
  String get peopleUnit => 'คน';
  @override
  String get closeBtn => 'ปิด';
  @override
  String get download => 'ดาวน์โหลด';
  @override
  String get genericError => 'เกิดข้อผิดพลาด';
}

class ThaiNavigation implements BaseNavigation {
  @override
  String get utilityTitle => 'บริการ';
  @override
  String get searchTitle => 'ค้นหาเส้นทาง';
  @override
  String get mapTitle => 'แผนที่รถไฟฟ้า';
  @override
  String get favoritesTitle => 'รายการโปรด';
  @override
  String get settingsTitle => 'ตั้งค่า';
}

class ThaiSearch implements BaseSearch {
  @override
  String get originLabel => 'สถานีต้นทาง';
  @override
  String get destLabel => 'สถานีปลายทาง';
  @override
  String get originHint => 'เลือกสถานีต้นทาง';
  @override
  String get destHint => 'เลือกสถานีปลายทาง';
  @override
  String get findRouteBtn => 'คำนวณเส้นทาง';
  @override
  String get selectStationTitle => 'คุณเดินทางจากสถานีใด?';
  @override
  String get selectStationSubtitle =>
      'แตะเลือกสถานีเพื่อเช็คอินและตั้งเป็นต้นทาง';
  @override
  String get loadingStations => 'กำลังโหลดข้อมูลสถานี...';
  @override
  String get calculatingRoute => 'กำลังค้นหาเส้นทางที่ดีที่สุด...';
  @override
  String get searchDesc =>
      'พิมพ์ชื่อสถานีเพื่อค้นหา\nรองรับ BTS, MRT, Airport Rail Link';
  @override
  String get noStationFound => 'ไม่พบสถานี';
  @override
  String get popularLandmark => 'สถานที่ยอดนิยม';
  @override
  String get customLocation => 'ตำแหน่งที่กำหนดเอง';
  @override
  String get searchPlaceholder => 'ค้นหาสถานีหรือสถานที่...';
  @override
  String get useCurrentLocation => 'ใช้ตำแหน่งปัจจุบันของคุณ';
  @override
  String get useCurrentLocationDesc =>
      'ค้นหาเส้นทางโดยเริ่มจากตำแหน่งที่คุณอยู่';
  @override
  String get locationDeniedSnack => 'ปฏิเสธการเข้าถึงตำแหน่งที่ตั้ง';
  @override
  String get locationFailedSnack => 'ไม่สามารถดึงข้อมูลตำแหน่งที่ตั้งได้';
  @override
  String get groupStations => 'สถานีรถไฟฟ้า';
  @override
  String get groupLandmarks => 'สถานที่สำคัญ';
  @override
  String get groupOtherTransit => 'จุดจอดรถสาธารณะอื่นๆ';
  @override
  String get groupPlaces => 'สถานที่ทั่วไป';
  @override
  String showMore(int count) => 'ดูเพิ่มเติม ($count)';
  @override
  String get noResultsFound => 'ไม่พบข้อมูลที่ค้นหา';
  @override
  String get clearAll => 'ล้างทั้งหมด';
  @override
  String get currentLocationNameTh => 'ตำแหน่งปัจจุบันของคุณ';
  @override
  String get currentLocationNameEn => '—';

  @override
  String get clearRoute => 'ล้างเส้นทาง';
  @override
  String get swapTooltip => 'สลับต้นทาง/ปลายทาง';
  @override
  String get fromPrefix => 'ต้นทาง:';
  @override
  String get toPrefix => 'ปลายทาง:';
  @override
  String get chooseDest => 'เลือกปลายทาง...';
  @override
  String get chooseOrigin => 'เลือกต้นทาง...';
}

class ThaiFavorites implements BaseFavorites {
  @override
  String get emptyFavTitle => 'ยังไม่มีสถานีโปรด';
  @override
  String get emptyFavSubtitle =>
      'ค้นหาสถานีและกดรูปหัวใจเพื่อบันทึกสถานีที่ใช้เป็นประจำ';
  @override
  String get emptyRouteTitle => 'ยังไม่มีเส้นทางที่บันทึก';
  @override
  String get emptyRouteSubtitle =>
      'คุณสามารถบันทึกเส้นทางที่ใช้ประจำหลังจากคำนวณเส้นทางแล้ว';
  @override
  String get setOriginBtn => 'ตั้งเป็นต้นทาง';
  @override
  String get setDestBtn => 'ตั้งเป็นปลายทาง';
  @override
  String get favStationsTab => 'สถานีโปรด';
  @override
  String get favRoutesTab => 'เส้นทางที่บันทึก';
  @override
  String get stationAddedFav => 'เพิ่มสถานีในรายการโปรดแล้ว';
  @override
  String get stationRemovedFav => 'ลบสถานีออกจากรายการโปรดแล้ว';
  @override
  String get unnamedRoute => 'เส้นทางไม่มีชื่อ';
}

class ThaiRouteResult implements BaseRouteResult {
  @override
  String get nextTrain => 'ขบวนถัดไป';
  @override
  String get trainArriving => 'รถกำลังเข้าสถานี';
  @override
  String get serviceEnded => 'หมดระยะบริการ';
  @override
  String get crowdLevel => 'คนรอ';
  @override
  String get crowdLow => 'โล่ง';
  @override
  String get crowdMedium => 'ปานกลาง';
  @override
  String get crowdHigh => 'หนาแน่น';
  @override
  String get crowdUnknown => 'ไม่มีข้อมูล';
  @override
  String get routeResultTitle => 'ผลการคำนวณเส้นทาง';
  @override
  String get totalFare => 'ค่าโดยสารรวม';
  @override
  String get totalTime => 'เวลาเดินทางประมาณ';
  @override
  String get stationsCount => 'สถานี';
  @override
  String get interchangeAt => 'เปลี่ยนสายที่';
  @override
  String get saveRouteBtn => 'บันทึกเส้นทาง';
  @override
  String get routeSavedSuccess => 'บันทึกเส้นทางสำเร็จ!';
  @override
  String get routeDeletedSuccess => 'ลบเส้นทางสำเร็จ!';
  @override
  String get linesCount => 'สาย';
  @override
  String get transfersCount => 'ต่อรถ';
  @override
  String get noRouteData => 'ไม่มีข้อมูลเส้นทาง';
  @override
  String get routeNameLabel => 'ชื่อเส้นทาง';
  @override
  String get routeNameHint => 'เช่น ไปทำงาน, กลับบ้าน';
  @override
  String get fareTitle => 'ค่าโดยสาร';
  @override
  String get routeRecommended => 'แนะนำ';
  @override
  String get routeSaver => 'ประหยัด (เดินเท้า)';
  @override
  String get walkTo => 'เดินเท้าไปยัง';
  @override
  String get fromLabel => 'จาก';
  @override
  String exitLabel(String exitCode) => 'ทางออก $exitCode';
  @override
  String get walkToStation => 'เดินไปสถานี';
  @override
  String get walkToDestination => 'เดินไปยังจุดหมาย';
  @override
  String get cardDiscount => 'ส่วนลดบัตรโดยสาร';
  @override
  String get accuracyWarning => 'เส้นทางนี้อาจไม่แม่นยำ 100%';
  @override
  String get accuracyBody =>
      'เนื่องจากไม่สามารถดึงข้อมูลทางออกของสถานีได้ ระบบจึงคำนวณระยะทางจากจุดกึ่งกลางสถานีแทน';
  @override
  String get reportIssueLink => 'คลิกที่นี่เพื่อรายงานปัญหา';
  @override
  String get reportDialogTitle => 'รายงานปัญหาเส้นทาง';
  @override
  String get reportDialogBody =>
      'ระบบจะส่งพิกัดและข้อมูลเส้นทางเพื่อให้ทีมงานนำไปปรับปรุง คุณต้องการดำเนินการต่อหรือไม่?';
  @override
  String get reportSuccess => 'ส่งรายงานปัญหาเรียบร้อยแล้ว!';
}

class ThaiErrors implements BaseErrors {
  @override
  String get errorSamePlaces => 'ต้นทางและปลายทางเป็นสถานที่เดียวกัน';
  @override
  String get errorNoRoute => 'ไม่พบเส้นทาง';
  @override
  String errorFailed(String error) => 'เกิดข้อผิดพลาด: $error';
  @override
  String get errorNoInternet =>
      'ไม่มีการเชื่อมต่ออินเทอร์เน็ต หยุดดาวน์โหลดแผนที่ชั่วคราว';
}

class ThaiDirections implements BaseDirections {
  @override
  String get dirToKhuKhot => 'ไปคูคต';
  @override
  String get dirToKheha => 'ไปเคหะฯ';
  @override
  String get dirToNationalStadium => 'ไปสนามกีฬาแห่งชาติ';
  @override
  String get dirToBangWa => 'ไปบางหว้า';
  @override
  String get dirToKrungThonBuri => 'ไปกรุงธนบุรี';
  @override
  String get dirToKhlongSan => 'ไปคลองสาน';
  @override
  String get dirCircleClockwise => 'วงกลม (ตามเข็ม)';
  @override
  String get dirCircleCounterClockwise => 'วงกลม (ทวนเข็ม)';
  @override
  String get dirToKhlongBangPhai => 'ไปคลองบางไผ่';
  @override
  String get dirToTaoPoon => 'ไปเตาปูน';
  @override
  String get dirToLatPhrao => 'ไปลาดพร้าว';
  @override
  String get dirToSamrong => 'ไปสำโรง';
  @override
  String get dirToSuvarnabhumi => 'ไปสุวรรณภูมิ';
  @override
  String get dirToPhayaThai => 'ไปพญาไท';
  @override
  String get dirToMinBuri => 'ไปมีนบุรี';
  @override
  String get dirToNonthaburiCivicCenter => 'ไปศูนย์ราชการนนทบุรี';
  @override
  String get dirToMuangThongThaniLake => 'ไปทะเลสาบเมืองทองธานี';
  @override
  String get dirToSiRatMuangThongThani => 'ไปศรีรัช (เมืองทองธานี)';
  @override
  String get dirToRangsit => 'ไปรังสิต';
  @override
  String get dirToKrungThepAphiwat => 'ไปกรุงเทพอภิวัฒน์';
  @override
  String get dirToTalingChan => 'ไปตลิ่งชัน';

  @override
  String getDirectionLabel(String lineId, int boundIndex, String fallback) {
    switch (lineId) {
      case 'BTS_SUKHUMVIT':
        return boundIndex == 0 ? dirToKhuKhot : dirToKheha;
      case 'BTS_SILOM':
        return boundIndex == 0 ? dirToNationalStadium : dirToBangWa;
      case 'BTS_GOLD':
        return boundIndex == 0 ? dirToKrungThonBuri : dirToKhlongSan;
      case 'MRT_BLUE':
        return boundIndex == 0 ? dirCircleClockwise : dirCircleCounterClockwise;
      case 'MRT_PURPLE':
        return boundIndex == 0 ? dirToKhlongBangPhai : dirToTaoPoon;
      case 'MRT_YELLOW':
        return boundIndex == 0 ? dirToLatPhrao : dirToSamrong;
      case 'ARL':
        return boundIndex == 0 ? dirToPhayaThai : dirToSuvarnabhumi;
      case 'MRT_PINK':
        return boundIndex == 0 ? dirToMinBuri : dirToNonthaburiCivicCenter;
      case 'MRT_PINK_BRANCH':
        return boundIndex == 0
            ? dirToMuangThongThaniLake
            : dirToSiRatMuangThongThani;
      case 'SRT_RED_NORTH':
        return boundIndex == 0 ? dirToRangsit : dirToKrungThepAphiwat;
      case 'SRT_RED_WEST':
        return boundIndex == 0 ? dirToTalingChan : dirToKrungThepAphiwat;
      default:
        return fallback;
    }
  }
}

class ThaiTransfers implements BaseTransfers {
  @override
  String get transferThaphraUp =>
      'ขึ้นบันไดเลื่อนไปชานชาลาชั้น 4 (สายวงกลม ไปทางจรัญฯ/เตาปูน) · เดิน ~1 นาที';
  @override
  String get transferThaphraDown =>
      'ลงบันไดเลื่อนไปชานชาลาชั้น 3 (สายกิ่ง ไปทางบางหว้า/หลักสอง) · เดิน ~1 นาที';
  @override
  String transferSiamSameLevel(int floor) =>
      'เดินสลับฝั่งชานชาลาที่ชั้นเดียวกัน (ชั้น $floor) · เดิน ~1 นาที';
  @override
  String get transferSiamUp =>
      'ขึ้นบันไดเลื่อนขึ้นไปชานชาลาชั้น 3 · เดิน ~1 นาที';
  @override
  String get transferSiamDown =>
      'ลงบันไดเลื่อนลงไปชานชาลาชั้น 4 · เดิน ~1 นาที';
  @override
  String get transferLatphraoYellow =>
      'ขึ้นบันไดเลื่อนขึ้นไปชานชาลารถไฟฟ้ายกระดับสายสีเหลือง · เดิน ~2 นาที';
  @override
  String get transferLatphraoBlue =>
      'ลงบันไดเลื่อนลงไปสถานีรถไฟฟ้าใต้ดินสายสีน้ำเงิน · เดิน ~2 นาที';
  @override
  String get transferPhayathai =>
      'เดินผ่านทางเชื่อมเพื่อเปลี่ยนชานชาลาต่างระดับ · เดิน ~2 นาที';
  @override
  String get transferSamrong =>
      'เดินผ่านทางเชื่อมสกายวอล์คเปลี่ยนชานชาลายกระดับ · เดิน ~2 นาที';
  @override
  String get transferHuamak =>
      'เดินผ่านทางเชื่อมสกายวอล์คเพื่อเปลี่ยนสาย · เดิน ~2 นาที';
  @override
  String transferAsokSukhumvit(String targetStation) =>
      'ออกทางออก 3 เพื่อเชื่อมต่อไปยังสถานี$targetStation · เดิน ~2 นาที';
  @override
  String transferSilomSaladaeng(String targetStation, String exitNum) =>
      'ออกทางออก $exitNum เพื่อเชื่อมต่อไปยังสถานี$targetStation · เดิน ~3 นาที';
  @override
  String transferMoChitChatuchak(String targetStation, String exits) =>
      'ออกทางออก $exits เพื่อเชื่อมต่อไปยังสถานี$targetStation · เดิน ~2 นาที';
  @override
  String interchangeWalk(int time) => 'เปลี่ยนสาย · เดิน ~$time นาที';
  @override
  String interchangeLevels(int time) =>
      'เปลี่ยนชานชาลาต่างระดับชั้น · เดิน ~$time นาที';
}

class ThaiProximity implements BaseProximity {
  @override
  String get nearbyAlertTitle => 'อยู่ใกล้สถานี!';
  @override
  String nearbyAlertBody(String stationName) =>
      'คุณเข้าใกล้สถานี $stationName ระยะ 200 เมตรแล้ว';
  @override
  String get nearestStationTitle => 'สถานีรถไฟฟ้าใกล้คุณที่สุด';
  @override
  String nearestStationBody(String stationName, String distance) =>
      'สถานี $stationName อยู่ห่างจากคุณ $distance';
  @override
  String get inAppNotifTitle => 'พบสถานีรถไฟฟ้าใกล้เคียง!';
  @override
  String inAppNotifBody(int count) =>
      'มี $count สถานีใกล้คุณ แตะเพื่อดูตัวเลือกเดินทาง';
  @override
  String get interconnectText => 'เชื่อมต่อ: ';
  @override
  String checkinSuccess(String stationName) =>
      'เช็คอินสถานี $stationName สำเร็จ และตั้งเป็นต้นทางแล้ว!';
  @override
  String nearStationWalk(String stationName, String time) =>
      'ใกล้สถานี$stationName · เดิน ~$time นาที';
  @override
  String promptDelayAtStation(String stationName) =>
      'คุณติดอยู่ที่สถานี $stationName หรือไม่?';
  @override
  String get promptDelayBody =>
      'แตะที่นี่เพื่อยืนยันว่ารถไฟฟ้ามีความล่าช้าหรือปกติ';
  @override
  String get normalStatusLabel => 'เดินรถปกติ';
  @override
  String get yesDelayedLabel => 'ใช่ ล่าช้า/ขัดข้อง';
  @override
  String get thankYouReportLabel => 'ขอบคุณที่ร่วมรายงานข้อมูลสถานการณ์';
  @override
  String delayedAtStation(String name) => 'คุณติดอยู่ที่สถานี $name หรือไม่?';
  @override
  String get detectedLonger => 'ระบบตรวจพบว่าคุณอยู่ที่สถานีนี้นานกว่าปกติ...';
}

class ThaiSettings implements BaseSettings {
  @override
  String get themeSetting => 'ธีม';
  @override
  String get themeDark => 'Dark Mode';
  @override
  String get themeLight => 'Light Mode';
  @override
  String get themeSystem => 'ตามระบบ';
  @override
  String get langSetting => 'ภาษา';
  @override
  String get langTh => 'ไทย';
  @override
  String get langEn => 'English';
  @override
  String get aboutSetting => 'เกี่ยวกับ';
  @override
  String get aboutDesc =>
      'แอปพลิเคชันวางแผนเดินทางรถไฟฟ้ากรุงเทพฯ พัฒนาด้วย Flutter & Riverpod';
  @override
  String get versionInfo => 'BKK Transit Planner\nv1.0.0';
  @override
  String get locationPermissionRequired => 'ต้องการสิทธิ์ระบุตำแหน่ง';
  @override
  String get locationPermissionDesc =>
      'แอป BKK Transit ต้องการสิทธิ์ระบุตำแหน่งของคุณ เพื่อตรวจหาและแจ้งเตือนสถานีที่อยู่ใกล้เคียงโดยรอบ กรุณากดเปิดสิทธิ์ในการตั้งค่า';
  @override
  String get openSettingsBtn => 'เปิดการตั้งค่า';
  @override
  String get offlineMapTitle => 'อัปเดตแผนที่ออฟไลน์';
  @override
  String get offlineMapSubtitle => 'ตรวจสอบและดาวน์โหลดการอัปเดตเพิ่มเติม';
  @override
  String get downloadDialogTitle => 'ดาวน์โหลดแผนที่อัปเดตใหม่';
  @override
  String get downloadDialogBody =>
      'กรุณารอสักครู่ขณะที่ระบบทำการดาวน์โหลดและติดตั้งข้อมูลแผนที่ออฟไลน์...';
  @override
  String get downloadStarted => 'เริ่มดาวน์โหลดการอัปเดตแผนที่แล้ว...';
  @override
  String get versionLabel => 'เวอร์ชัน';
  @override
  String get disclaimer =>
      'ข้อมูลและเส้นทางในแอปพลิเคชันเป็นเพียงการประมาณการเพื่อช่วยในการตัดสินใจ';
  @override
  String get copyright => '© 2026 BKK Transit Planner';
  @override
  String get viewLicenses => 'ดูลิขสิทธิ์ซอฟต์แวร์';
  @override
  String get offlineMapDownloading => 'ดาวน์โหลดแผนที่ออฟไลน์';
  @override
  String get offlineMapPreparing =>
      'กำลังจัดเตรียมแผนที่สำหรับใช้งานออฟไลน์...';
  @override
  String offlineMapDownloaded(int current, int total) =>
      'ดาวน์โหลดแล้ว $current / $total รูป';
  @override
  String offlineMapCachedAndNew(int cached, int newCount) =>
      'เก็บในเครื่องแล้ว: $cached รูป | โหลดใหม่: $newCount รูป';
  @override
  String prefetchProgress(String current, String total) =>
      'ดาวน์โหลดแล้ว $current / $total รูป';
  @override
  String prefetchStats(String cached) => 'เก็บในเครื่องแล้ว: $cached';
}

class ThaiJourney implements BaseJourney {
  @override
  String get startJourneyBtn => 'เริ่มการเดินทาง';
  @override
  String get simulateJourneyBtn => 'จำลองการเดินทาง';
  @override
  String get endJourneyBtn => 'สิ้นสุดการเดินทาง';
  @override
  String get currentStationLabel => 'สถานีปัจจุบัน';
  @override
  String get nextStationLabel => 'สถานีถัดไป';
  @override
  String get transferAtLabel => 'เปลี่ยนขบวนที่';
  @override
  String get arrivedLabel => 'ถึงจุดหมายแล้ว';
  @override
  String get walkToLabel => 'เดินเท้าไปยัง';
  @override
  String get simulationMode => 'โหมดจำลอง GPS';
  @override
  String get nextSimulationBtn => 'สถานีถัดไป (จำลอง)';
  @override
  String get stationsCount => 'สถานี';
  @override
  String get walkingConnection => 'เดินเท้าเชื่อมต่อ';
  @override
  String get travelingStatus => 'กำลังเดินทาง';
  @override
  String get walkingAction => 'เดินเท้า';
  @override
  String walkRemaining(String meters) => '🚶 เดินเท้าอีก $meters ม.';
  @override
  String headingTo(String dest) => 'มุ่งหน้า $dest';
  @override
  String get transitRideAction => '🚇 นั่งรถไฟฟ้า';
  @override
  String etaRemaining(int minutes) => '⏱ อีก $minutes นาที';
  @override
  String speedMeasure(String speed) => '💨 $speed กม./ชม';
  @override
  String get arrivedText => 'ถึงจุดหมายแล้ว';
}

class ThaiAuth implements BaseAuth {
  @override
  String get loginTitle => 'เข้าสู่ระบบ';
  @override
  String get registerTitle => 'สมัครสมาชิก';
  @override
  String get emailLabel => 'อีเมล';
  @override
  String get emailHint => 'กรอกอีเมลของคุณ';
  @override
  String get passwordLabel => 'รหัสผ่าน';
  @override
  String get passwordHint => 'กรอกรหัสผ่านของคุณ';
  @override
  String get confirmPasswordLabel => 'ยืนยันรหัสผ่าน';
  @override
  String get confirmPasswordHint => 'กรอกรหัสผ่านอีกครั้ง';
  @override
  String get displayNameLabel => 'ชื่อผู้ใช้';
  @override
  String get displayNameHint => 'กรอกชื่อเล่นหรือชื่อแสดงตัวตน';
  @override
  String get loginBtn => 'เข้าสู่ระบบ';
  @override
  String get registerBtn => 'สมัครสมาชิก';
  @override
  String get googleLoginBtn => 'เข้าสู่ระบบด้วย Google';
  @override
  String get dontHaveAccount => 'ยังไม่มีบัญชีผู้ใช้? สมัครสมาชิก';
  @override
  String get alreadyHaveAccount => 'มีบัญชีผู้ใช้อยู่แล้ว? เข้าสู่ระบบ';
  @override
  String get profileTitle => 'ข้อมูลผู้ใช้งาน';
  @override
  String get signOutBtn => 'ออกจากระบบ';
  @override
  String get signInToSync => 'เข้าสู่ระบบเพื่อซิงค์ข้อมูล';
  @override
  String get signInToSyncDesc =>
      'บันทึกสถานีโปรดและเส้นทางเดินรถเพื่อใช้งานข้ามอุปกรณ์ได้ทุกที่';
  @override
  String get invalidEmail => 'รูปแบบอีเมลไม่ถูกต้อง';
  @override
  String get passwordTooShort => 'รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร';
  @override
  String get passwordsDoNotMatch => 'รหัสผ่านไม่ตรงกัน';
  @override
  String get nameRequired => 'กรุณากรอกชื่อผู้ใช้';
  @override
  String get loginFailed => 'เข้าสู่ระบบล้มเหลว กรุณาตรวจสอบอีเมลและรหัสผ่าน';
  @override
  String get registrationFailed =>
      'สมัครสมาชิกไม่สำเร็จ อีเมลนี้อาจถูกใช้งานไปแล้ว';
  @override
  String get syncSuccess => 'ซิงค์ข้อมูลสำเร็จ!';
  @override
  String get defaultUsername => 'ผู้ใช้';
  @override
  String get orDivider => 'หรือ';
}

class ThaiUtility implements BaseUtility {
  @override
  String get statusSectionTitle => 'สถานะการเดินรถไฟฟ้า';
  @override
  String get newsSectionTitle => 'ข่าวสารและประกาศ';
  @override
  String get noNewsAnnouncements =>
      'ไม่มีข่าวสารหรือประกาศเดินรถขัดข้องในขณะนี้';
  @override
  String get cardsSectionTitle => 'บัตรโดยสารและสิทธิ์ของฉัน';
  @override
  String get cardsSubtitle =>
      'เลือกสิทธิ์ส่วนลดของคุณเพื่อการแสดงผลราคาในระบบเดินทางอย่างถูกต้อง';
  @override
  String get rabbitCardName => 'บัตรแรบบิท (Rabbit)';
  @override
  String get mrtCardName => 'บัตรเอ็มอาร์ที (MRT)';
  @override
  String get arlCardName => 'แอร์พอร์ตลิงก์ (ARL)';
  @override
  String get srtCardName => 'รถไฟสายสีแดง (SRT)';
  @override
  String get optionStandardTitle => 'บุคคลทั่วไป';
  @override
  String get optionStudentTitle => 'นักเรียน/นักศึกษา';
  @override
  String get optionSeniorTitle => 'ผู้สูงอายุ';
  @override
  String get optionTripPackageTitle => 'เหมาเที่ยว (BTS)';
  @override
  String get optionStandardSubtitle => 'ราคาปกติ';
  @override
  String get optionStudentBtsSubtitle => 'ลด 10%';
  @override
  String get optionSeniorBtsSubtitle => 'ลด 50%';
  @override
  String get optionTripPackageBtsSubtitle => '30 บาท/เที่ยว';
  @override
  String get optionStudentMrtSubtitle => 'ลด 10%';
  @override
  String get optionSeniorMrtSubtitle => 'ลด 50%';
  @override
  String get optionStudentArlSubtitle => 'ลด 20%';
  @override
  String get optionSeniorArlSubtitle => 'ลด 50%';
  @override
  String get optionStudentSrtSubtitle => 'ลด 10%';
  @override
  String get optionSeniorSrtSubtitle => 'ลด 50%';
  @override
  String get debugSimGpsTitle => 'จำลองตำแหน่งพิกัด GPS';
  @override
  String get debugSimGpsDisabled =>
      'ปิดใช้งาน (ใช้ GPS จริง)\n(โหมด Debug เท่านั้น)';
  @override
  String debugSimGpsActive(String lat, String lng) =>
      'กำลังจำลอง: $lat, $lng\n(โหมด Debug เท่านั้น)';
  @override
  String get debugSimGpsDialogTitle => 'จำลองตำแหน่งพิกัด';
  @override
  String get debugSimGpsDisableOption => 'ปิดการจำลอง';
  @override
  String get debugSimGpsDisableSubtitle =>
      'ใช้ GPS จริงจากเครื่องหรือ Emulator';
  @override
  String get debugSimGpsDisabledSnack => 'ปิดการจำลองตำแหน่งแล้ว';
  @override
  String debugSimGpsEnabledSnack(String stationName) =>
      'กำลังจำลองตำแหน่งที่ $stationName';
  @override
  String get officialAnnouncementTitle => 'ข่าวประชาสัมพันธ์';
  @override
  String get reportDelayTitle => 'รายงานปัญหาหรือความล่าช้า';
  @override
  String get submitReportTitle => 'รายงานปัญหาจราจรและเหตุล่าช้า';
  @override
  String get selectLineLabel => 'เลือกสายรถไฟฟ้า';
  @override
  String get selectLineHint => 'กรุณาเลือกสายรถไฟฟ้า';
  @override
  String get selectStationLabel => 'เลือกสถานีรถไฟฟ้า';
  @override
  String get selectLineFirstHint => 'กรุณาเลือกสายรถไฟฟ้าก่อน';
  @override
  String get selectStationHint => 'กรุณาเลือกสถานี';
  @override
  String get delayIntensityLabel => 'ระดับความหนาแน่น / ล่าช้า';
  @override
  String get normalSmoothLabel => 'ปกติ/สะดวกสบาย';
  @override
  String get severeDelayLabel => 'แน่นมาก/รถไฟขัดข้อง';
  @override
  String get submitReportBtn => 'ส่งรายงานข้อมูล';
  @override
  String get errorLoadingStatus => 'เกิดข้อผิดพลาดในการโหลดข้อมูล';
  @override
  String get reportSuccessSnack => 'ส่งรายงานสำเร็จแล้ว';
  @override
  String get lineBtsSukhumvit => 'BTS สายสุขุมวิท';
  @override
  String get lineBtsSilom => 'BTS สายสีลม';
  @override
  String get lineMrtBlue => 'MRT สายสีน้ำเงิน';
  @override
  String get lineMrtPurple => 'MRT สายสีม่วง';
  @override
  String get lineMrtYellow => 'MRT สายสีเหลือง';
  @override
  String get lineMrtPink => 'MRT สายสีชมพู';
  @override
  String get lineArl => 'แอร์พอร์ตลิงก์';
  @override
  String get lineSrtRed => 'สายสีแดง';
  @override
  String get reportDelayDesc =>
      'ร่วมแจ้งความหนาแน่นและความล่าช้าในระบบรถไฟฟ้าเพื่อเป็นประโยชน์ต่อผู้เดินทางท่านอื่น';
}
