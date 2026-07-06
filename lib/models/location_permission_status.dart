/// Represents the result of a location permission request.
///
/// Used by [LocationService.requestLocationPermission] to communicate
/// all possible permission outcomes to callers.
enum LocationPermissionStatus {
  /// Permission was granted — proceed normally.
  granted,

  /// Permission was denied this time — can still re-request later.
  denied,

  /// User selected "Don't ask again" (Android) or restricted (iOS).
  /// Cannot re-request programmatically — must direct user to app Settings.
  permanentlyDenied,
}
