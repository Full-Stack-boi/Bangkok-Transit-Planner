class Formatters {
  /// Formats travel duration in minutes into clean human readable string (e.g. "~45 นาที" or "~1 ชม. 15 นาที")
  static String formatDuration(double totalMinutes, String localeCode) {
    final mins = totalMinutes.round();
    if (mins < 60) {
      return localeCode == 'th' ? '~$mins นาที' : '~$mins mins';
    }
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    if (remainingMins == 0) {
      return localeCode == 'th' ? '~$hours ชม.' : '~$hours hr';
    }
    return localeCode == 'th'
        ? '~$hours ชม. $remainingMins นาที'
        : '~$hours hr $remainingMins min';
  }
}
