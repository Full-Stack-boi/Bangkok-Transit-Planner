import 'localizations/base_localizations.dart';
import 'localizations/th_localizations.dart';
import 'localizations/en_localizations.dart';

export 'localizations/base_localizations.dart';

class AppLocalizations {
  final String localeCode;
  late final BaseLocalizations _delegate;

  AppLocalizations(this.localeCode) {
    _delegate = _getDelegate();
  }

  BaseLocalizations _getDelegate() {
    switch (localeCode) {
      case 'th':
        return ThaiLocalizations();
      default:
        return EnglishLocalizations();
    }
  }

  // Delegate all namespaces to the active language implementation
  BaseCommon get common => _delegate.common;
  BaseNavigation get navigation => _delegate.navigation;
  BaseSearch get search => _delegate.search;
  BaseFavorites get favorites => _delegate.favorites;
  BaseRouteResult get routeResult => _delegate.routeResult;
  BaseErrors get errors => _delegate.errors;
  BaseDirections get directions => _delegate.directions;
  BaseTransfers get transfers => _delegate.transfers;
  BaseProximity get proximity => _delegate.proximity;
  BaseSettings get settings => _delegate.settings;
  BaseJourney get journey => _delegate.journey;
}
