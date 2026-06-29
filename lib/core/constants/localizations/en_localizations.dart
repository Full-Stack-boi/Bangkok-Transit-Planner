import 'base_localizations.dart';

class EnglishLocalizations implements BaseLocalizations {
  @override
  final common = EnglishCommon();
  @override
  final navigation = EnglishNavigation();
  @override
  final search = EnglishSearch();
  @override
  final favorites = EnglishFavorites();
  @override
  final routeResult = EnglishRouteResult();
  @override
  final errors = EnglishErrors();
  @override
  final directions = EnglishDirections();
  @override
  final transfers = EnglishTransfers();
  @override
  final proximity = EnglishProximity();
  @override
  final settings = EnglishSettings();
  @override
  final journey = EnglishJourney();
  @override
  final auth = EnglishAuth();
  @override
  final utility = EnglishUtility();
}

class EnglishCommon implements BaseCommon {
  @override
  String get appTitle => 'BKK Transit';
  @override
  String get cancelBtn => 'Cancel';
  @override
  String get saveBtn => 'Save';
  @override
  String get minutesUnit => 'min';
  @override
  String get secondsUnit => 'sec';
  @override
  String get currencyUnit => 'THB';
  @override
  String get kmUnit => 'km';
  @override
  String get metersUnit => 'm';
  @override
  String get total => 'Total';
  @override
  String get laterBtn => 'Later';
  @override
  String get errorOccurred => 'An error occurred';
}

class EnglishNavigation implements BaseNavigation {
  @override
  String get utilityTitle => 'Utility';
  @override
  String get searchTitle => 'Search Route';
  @override
  String get mapTitle => 'Transit Map';
  @override
  String get favoritesTitle => 'Favorites';
  @override
  String get settingsTitle => 'Settings';
}

class EnglishSearch implements BaseSearch {
  @override
  String get originLabel => 'Origin Station';
  @override
  String get destLabel => 'Destination Station';
  @override
  String get originHint => 'Select origin station';
  @override
  String get destHint => 'Select destination station';
  @override
  String get findRouteBtn => 'Find Route';
  @override
  String get selectStationTitle => 'Which station are you travelling from?';
  @override
  String get selectStationSubtitle => 'Tap a station to check-in and set as origin.';
  @override
  String get loadingStations => 'Loading station data...';
  @override
  String get calculatingRoute => 'Calculating optimal route...';
  @override
  String get searchDesc => 'Type station name to search\nSupports BTS, MRT, Airport Rail Link';
  @override
  String get noStationFound => 'No station found';
  @override
  String get popularLandmark => 'Popular Landmark';
  @override
  String get customLocation => 'Custom Location';
  @override
  String get searchPlaceholder => 'Search station or place...';
  @override
  String get useCurrentLocation => 'Use Current Location';
  @override
  String get useCurrentLocationDesc => 'Find routes starting from where you are';
  @override
  String get locationDeniedSnack => 'Location permission denied';
  @override
  String get locationFailedSnack => 'Unable to retrieve location';
  @override
  String get groupStations => 'Transit Stations';
  @override
  String get groupLandmarks => 'Landmarks';
  @override
  String get groupOtherTransit => 'Other Transit Stops';
  @override
  String get groupPlaces => 'Places';
  @override
  String showMore(int count) => 'Show more ($count)';
  @override
  String get noResultsFound => 'No results found';
}

class EnglishFavorites implements BaseFavorites {
  @override
  String get emptyFavTitle => 'No favorite stations yet';
  @override
  String get emptyFavSubtitle => 'Search stations and tap the heart icon to save them here.';
  @override
  String get emptyRouteTitle => 'No saved routes yet';
  @override
  String get emptyRouteSubtitle => 'You can save your regular routes after calculating them.';
  @override
  String get setOriginBtn => 'Set as Origin';
  @override
  String get setDestBtn => 'Set as Dest';
  @override
  String get favStationsTab => 'Favorite Stations';
  @override
  String get favRoutesTab => 'Saved Routes';
  @override
  String get stationAddedFav => 'Station added to favorites';
  @override
  String get stationRemovedFav => 'Station removed from favorites';
  @override
  String get unnamedRoute => 'Unnamed Route';
}

class EnglishRouteResult implements BaseRouteResult {
  @override
  String get nextTrain => 'Next train';
  @override
  String get trainArriving => 'Arriving now';
  @override
  String get serviceEnded => 'Service ended';
  @override
  String get crowdLevel => 'Crowd';
  @override
  String get crowdLow => 'Low';
  @override
  String get crowdMedium => 'Medium';
  @override
  String get crowdHigh => 'High';
  @override
  String get crowdUnknown => 'Unknown';
  @override
  String get routeResultTitle => 'Route Calculation Result';
  @override
  String get totalFare => 'Total Fare';
  @override
  String get totalTime => 'Approx. Time';
  @override
  String get stationsCount => 'stations';
  @override
  String get interchangeAt => 'Interchange at';
  @override
  String get saveRouteBtn => 'Save Route';
  @override
  String get routeSavedSuccess => 'Route saved successfully!';
  @override
  String get routeDeletedSuccess => 'Route deleted successfully!';
  @override
  String get linesCount => 'lines';
  @override
  String get transfersCount => 'transfers';
  @override
  String get noRouteData => 'No route data available';
  @override
  String get routeNameLabel => 'Route Name';
  @override
  String get routeNameHint => 'e.g., Work, Home';
  @override
  String get fareTitle => 'Fare';
  @override
  String get routeRecommended => 'Recommended';
  @override
  String get routeSaver => 'Saver (Walk)';
  @override
  String get walkTo => 'Walk to';
  @override
  String get fromLabel => 'From';
  @override
  String exitLabel(String exitCode) => 'Exit $exitCode';
  @override
  String get walkToStation => 'Walk to station';
  @override
  String get walkToDestination => 'Walk to destination';
}

class EnglishErrors implements BaseErrors {
  @override
  String get errorSamePlaces => 'Origin and destination cannot be the same';
  @override
  String get errorNoRoute => 'No route found';
  @override
  String errorFailed(String error) => 'Error occurred: $error';
  @override
  String get errorNoInternet => 'No internet connection. Map prefetching paused.';
}

class EnglishDirections implements BaseDirections {
  @override
  String get dirToKhuKhot => 'to Khu Khot';
  @override
  String get dirToKheha => 'to Kheha';
  @override
  String get dirToNationalStadium => 'to National Stadium';
  @override
  String get dirToBangWa => 'to Bang Wa';
  @override
  String get dirToKrungThonBuri => 'to Krung Thon Buri';
  @override
  String get dirToKhlongSan => 'to Khlong San';
  @override
  String get dirCircleClockwise => 'Circle Loop (Clockwise)';
  @override
  String get dirCircleCounterClockwise => 'Circle Loop (Counter-Clockwise)';
  @override
  String get dirToKhlongBangPhai => 'to Khlong Bang Phai';
  @override
  String get dirToTaoPoon => 'to Tao Poon';
  @override
  String get dirToLatPhrao => 'to Lat Phrao';
  @override
  String get dirToSamrong => 'to Samrong';
  @override
  String get dirToSuvarnabhumi => 'to Suvarnabhumi';
  @override
  String get dirToPhayaThai => 'to Phaya Thai';

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
      default:
        return fallback;
    }
  }
}

class EnglishTransfers implements BaseTransfers {
  @override
  String get transferThaphraUp => 'Go up to Level 4 platform (Circle Line towards Charan / Tao Poon) · Walk ~1 min';
  @override
  String get transferThaphraDown => 'Go down to Level 3 platform (Branch Line towards Bang Wa / Lak Song) · Walk ~1 min';
  @override
  String transferSiamSameLevel(int floor) => 'Cross-platform transfer on the same level (Level $floor) · Walk ~1 min';
  @override
  String get transferSiamUp => 'Go up to Level 3 platform · Walk ~1 min';
  @override
  String get transferSiamDown => 'Go down to Level 4 platform · Walk ~1 min';
  @override
  String get transferLatphraoYellow => 'Go up to the elevated Yellow Line platform · Walk ~2 min';
  @override
  String get transferLatphraoBlue => 'Go down to the underground Blue Line platform · Walk ~2 min';
  @override
  String get transferPhayathai => 'Walk via connection link to the other station level · Walk ~2 min';
  @override
  String get transferSamrong => 'Walk via skywalk connection link to the other line · Walk ~2 min';
  @override
  String get transferHuamak => 'Walk via skywalk transfer bridge to the other line · Walk ~2 min';
  @override
  String transferAsokSukhumvit(String targetStation) => 'Take Exit 3 to connect to $targetStation Station · Walk ~2 min';
  @override
  String transferSilomSaladaeng(String targetStation, String exitNum) => 'Take Exit $exitNum to connect to $targetStation Station · Walk ~3 min';
  @override
  String transferMoChitChatuchak(String targetStation, String exits) => 'Take Exit $exits to connect to $targetStation Station · Walk ~2 min';
  @override
  String interchangeWalk(int time) => 'Transfer · Walk ~$time min';
  @override
  String interchangeLevels(int time) => 'Transfer platforms (different levels) · Walk ~$time min';
}

class EnglishProximity implements BaseProximity {
  @override
  String get nearbyAlertTitle => 'Station Nearby!';
  @override
  String nearbyAlertBody(String stationName) => 'You are within 200m of $stationName station';
  @override
  String get nearestStationTitle => 'Your Nearest Station';
  @override
  String nearestStationBody(String stationName, String distance) => '$stationName station is $distance away';
  @override
  String get inAppNotifTitle => 'Nearby stations found!';
  @override
  String inAppNotifBody(int count) => '$count stations nearby. Tap to view travel options.';
  @override
  String get interconnectText => 'Interchange: ';
  @override
  String checkinSuccess(String stationName) => 'Checked in to $stationName and set as origin!';
  @override
  String nearStationWalk(String stationName, String time) => 'Near $stationName station · ~$time min walk';
}

class EnglishSettings implements BaseSettings {
  @override
  String get themeSetting => 'Theme';
  @override
  String get themeDark => 'Dark Mode';
  @override
  String get themeLight => 'Light Mode';
  @override
  String get themeSystem => 'System Theme';
  @override
  String get langSetting => 'Language';
  @override
  String get langTh => 'ไทย';
  @override
  String get langEn => 'English';
  @override
  String get aboutSetting => 'About';
  @override
  String get aboutDesc => 'Bangkok Transit Planning Application built with Flutter & Riverpod';
  @override
  String get versionInfo => 'BKK Transit Planner\nv1.0.0';
  @override
  String get locationPermissionRequired => 'Location Permission Required';
  @override
  String get locationPermissionDesc => 'BKK Transit requires location permission to detect and notify you about nearby transit stations. Please enable it in settings.';
  @override
  String get openSettingsBtn => 'Open Settings';
}

class EnglishJourney implements BaseJourney {
  @override
  String get startJourneyBtn => 'Start Journey';
  @override
  String get simulateJourneyBtn => 'Simulate Journey';
  @override
  String get endJourneyBtn => 'End Journey';
  @override
  String get currentStationLabel => 'Current Station';
  @override
  String get nextStationLabel => 'Next Station';
  @override
  String get transferAtLabel => 'Transfer at';
  @override
  String get arrivedLabel => 'Arrived at destination';
  @override
  String get walkToLabel => 'Walk to';
  @override
  String get simulationMode => 'GPS Simulation Mode';
  @override
  String get nextSimulationBtn => 'Next Station (Sim)';
  @override
  String get stationsCount => 'stations';
}

class EnglishAuth implements BaseAuth {
  @override
  String get loginTitle => 'Login';
  @override
  String get registerTitle => 'Register';
  @override
  String get emailLabel => 'Email';
  @override
  String get emailHint => 'Enter your email';
  @override
  String get passwordLabel => 'Password';
  @override
  String get passwordHint => 'Enter your password';
  @override
  String get confirmPasswordLabel => 'Confirm Password';
  @override
  String get confirmPasswordHint => 'Enter your password again';
  @override
  String get displayNameLabel => 'Display Name';
  @override
  String get displayNameHint => 'Enter your display name';
  @override
  String get loginBtn => 'Login';
  @override
  String get registerBtn => 'Register';
  @override
  String get googleLoginBtn => 'Sign In with Google';
  @override
  String get dontHaveAccount => "Don't have an account? Register";
  @override
  String get alreadyHaveAccount => 'Already have an account? Login';
  @override
  String get profileTitle => 'User Profile';
  @override
  String get signOutBtn => 'Sign Out';
  @override
  String get signInToSync => 'Sign in to sync data';
  @override
  String get signInToSyncDesc => 'Save favorite stations and routes to use them across devices.';
  @override
  String get invalidEmail => 'Invalid email address format';
  @override
  String get passwordTooShort => 'Password must be at least 6 characters long';
  @override
  String get passwordsDoNotMatch => 'Passwords do not match';
  @override
  String get nameRequired => 'Display name is required';
  @override
  String get loginFailed => 'Login failed. Please check your credentials.';
  @override
  String get registrationFailed => 'Registration failed. Email might already be in use.';
  @override
  String get syncSuccess => 'Data synced successfully!';
}

class EnglishUtility implements BaseUtility {
  @override
  String get statusSectionTitle => 'Transit Service Status';
  @override
  String get newsSectionTitle => 'Transit News & Alerts';
  @override
  String get cardsSectionTitle => 'My Transit Cards & Passes';
  @override
  String get cardsSubtitle =>
      'Configure your active cards to display customized fares across the map.';
  @override
  String get rabbitCardName => 'Rabbit Card';
  @override
  String get mrtCardName => 'MRT Card';
  @override
  String get arlCardName => 'ARL Smart Pass';
  @override
  String get optionStandardTitle => 'Standard';
  @override
  String get optionStudentTitle => 'Student';
  @override
  String get optionSeniorTitle => 'Senior';
  @override
  String get optionTripPackageTitle => 'Trip Package';
  @override
  String get optionStandardSubtitle => 'Regular fare';
  @override
  String get optionStudentBtsSubtitle => '10% off';
  @override
  String get optionSeniorBtsSubtitle => '50% off';
  @override
  String get optionTripPackageBtsSubtitle => 'Flat 30 \u0e3f';
  @override
  String get optionStudentMrtSubtitle => '10% off';
  @override
  String get optionSeniorMrtSubtitle => '50% off';
  @override
  String get optionStudentArlSubtitle => '20% off';
  @override
  String get optionSeniorArlSubtitle => '50% off';
  @override
  String get debugSimGpsTitle => 'Simulate GPS Location';
  @override
  String get debugSimGpsDisabled => 'Disabled (Using Real GPS)\n(Debug Mode Only)';
  @override
  String debugSimGpsActive(String lat, String lng) =>
      'Simulating at: $lat, $lng\n(Debug Mode Only)';
  @override
  String get debugSimGpsDialogTitle => 'Simulate Location';
  @override
  String get debugSimGpsDisableOption => 'Disable Simulation';
  @override
  String get debugSimGpsDisableSubtitle => 'Use real hardware/emulator GPS';
  @override
  String get debugSimGpsDisabledSnack => 'Mock location disabled';
  @override
  String debugSimGpsEnabledSnack(String stationName) =>
      'Simulating at $stationName';
}
