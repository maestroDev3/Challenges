import '../l10n/app_localizations.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Datum als „06.10.“ bzw. „06.10.2026“ – Reihenfolge und Trenner je Sprache
/// (ohne intl-Datumsdaten).
String formatDate(AppLocalizations l10n, DateTime d, {bool withYear = false}) =>
    withYear
        ? l10n.dateWithYear(_two(d.day), _two(d.month), '${d.year}')
        : l10n.dateShort(_two(d.day), _two(d.month));

/// Kurzer Wochentag, 1 = Montag.
String weekdayShort(AppLocalizations l10n, int weekday) =>
    l10n.weekdayShort('$weekday');

/// Kurzer Wochentag mit Datum, z. B. „Sa, 24.10.“.
String formatWeekdayDate(AppLocalizations l10n, DateTime d) =>
    '${weekdayShort(l10n, d.weekday)}, ${formatDate(l10n, d)}';

/// Monat mit Jahr, z. B. „Oktober 2026“.
String formatMonth(AppLocalizations l10n, DateTime d) =>
    '${l10n.monthName('${d.month}')} ${d.year}';

/// Restzeit als „13:22“ (Stunden:Minuten).
String formatRemaining(Duration d) {
  final minutes = d.inMinutes;
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
}

/// Stoppuhr „03:05“ bzw. „1:03:05“ ab einer Stunde.
String formatStopwatch(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
