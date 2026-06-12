abstract class BaseLocalizations {
  BaseCommon get common;
  BaseNavigation get navigation;
  BaseSearch get search;
  BaseFavorites get favorites;
  BaseRouteResult get routeResult;
  BaseErrors get errors;
  BaseDirections get directions;
  BaseTransfers get transfers;
  BaseProximity get proximity;
  BaseSettings get settings;
  BaseJourney get journey;
  BaseAuth get auth;
}

abstract class BaseCommon {
  String get appTitle;
  String get cancelBtn;
  String get saveBtn;
  String get minutesUnit;
  String get secondsUnit;
  String get currencyUnit;
  String get kmUnit;
  String get metersUnit;
  String get total;
  String get laterBtn;
  String get errorOccurred;
}

abstract class BaseNavigation {
  String get searchTitle;
  String get mapTitle;
  String get favoritesTitle;
  String get settingsTitle;
}

abstract class BaseSearch {
  String get originLabel;
  String get destLabel;
  String get originHint;
  String get destHint;
  String get findRouteBtn;
  String get selectStationTitle;
  String get selectStationSubtitle;
  String get loadingStations;
  String get searchDesc;
  String get noStationFound;
  String get popularLandmark;
  String get customLocation;
  String get searchPlaceholder;
  String get useCurrentLocation;
  String get useCurrentLocationDesc;
  String get locationDeniedSnack;
  String get locationFailedSnack;
}

abstract class BaseFavorites {
  String get emptyFavTitle;
  String get emptyFavSubtitle;
  String get emptyRouteTitle;
  String get emptyRouteSubtitle;
  String get setOriginBtn;
  String get setDestBtn;
  String get favStationsTab;
  String get favRoutesTab;
  String get stationAddedFav;
  String get stationRemovedFav;
  String get unnamedRoute;
}

abstract class BaseRouteResult {
  String get nextTrain;
  String get trainArriving;
  String get serviceEnded;
  String get crowdLevel;
  String get crowdLow;
  String get crowdMedium;
  String get crowdHigh;
  String get crowdUnknown;
  String get routeResultTitle;
  String get totalFare;
  String get totalTime;
  String get stationsCount;
  String get interchangeAt;
  String get saveRouteBtn;
  String get routeSavedSuccess;
  String get routeDeletedSuccess;
  String get linesCount;
  String get transfersCount;
  String get noRouteData;
  String get routeNameLabel;
  String get routeNameHint;
  String get fareTitle;
  String get routeRecommended;
  String get routeSaver;
  String get walkTo;
  String get fromLabel;
}

abstract class BaseErrors {
  String get errorSamePlaces;
  String get errorNoRoute;
  String errorFailed(String error);
}

abstract class BaseDirections {
  String get dirToKhuKhot;
  String get dirToKheha;
  String get dirToNationalStadium;
  String get dirToBangWa;
  String get dirToKrungThonBuri;
  String get dirToKhlongSan;
  String get dirCircleClockwise;
  String get dirCircleCounterClockwise;
  String get dirToKhlongBangPhai;
  String get dirToTaoPoon;
  String get dirToLatPhrao;
  String get dirToSamrong;
  String get dirToSuvarnabhumi;
  String get dirToPhayaThai;
  String getDirectionLabel(String lineId, int boundIndex, String fallback);
}

abstract class BaseTransfers {
  String get transferThaphraUp;
  String get transferThaphraDown;
  String transferSiamSameLevel(int floor);
  String get transferSiamUp;
  String get transferSiamDown;
  String get transferLatphraoYellow;
  String get transferLatphraoBlue;
  String get transferPhayathai;
  String get transferSamrong;
  String get transferHuamak;
  String interchangeWalk(int time);
  String interchangeLevels(int time);
}

abstract class BaseProximity {
  String get nearbyAlertTitle;
  String nearbyAlertBody(String stationName);
  String get nearestStationTitle;
  String nearestStationBody(String stationName, String distance);
  String get inAppNotifTitle;
  String inAppNotifBody(int count);
  String get interconnectText;
  String checkinSuccess(String stationName);
  String nearStationWalk(String stationName, String time);
}

abstract class BaseSettings {
  String get themeSetting;
  String get themeDark;
  String get themeLight;
  String get themeSystem;
  String get langSetting;
  String get langTh;
  String get langEn;
  String get aboutSetting;
  String get aboutDesc;
  String get versionInfo;
  String get locationPermissionRequired;
  String get locationPermissionDesc;
  String get openSettingsBtn;
}

abstract class BaseJourney {
  String get startJourneyBtn;
  String get endJourneyBtn;
  String get currentStationLabel;
  String get nextStationLabel;
  String get transferAtLabel;
  String get arrivedLabel;
  String get walkToLabel;
  String get simulationMode;
  String get nextSimulationBtn;
  String get stationsCount;
}

abstract class BaseAuth {
  String get loginTitle;
  String get registerTitle;
  String get emailLabel;
  String get emailHint;
  String get passwordLabel;
  String get passwordHint;
  String get confirmPasswordLabel;
  String get confirmPasswordHint;
  String get displayNameLabel;
  String get displayNameHint;
  String get loginBtn;
  String get registerBtn;
  String get googleLoginBtn;
  String get dontHaveAccount;
  String get alreadyHaveAccount;
  String get profileTitle;
  String get signOutBtn;
  String get signInToSync;
  String get signInToSyncDesc;
  String get invalidEmail;
  String get passwordTooShort;
  String get passwordsDoNotMatch;
  String get nameRequired;
  String get loginFailed;
  String get registrationFailed;
  String get syncSuccess;
}
}
