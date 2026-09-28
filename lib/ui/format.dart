/// Datum als „06.10.“ bzw. „06.10.2026“ (ohne intl-Paket).
String formatDate(DateTime d, {bool withYear = false}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final base = '${two(d.day)}.${two(d.month)}.';
  return withYear ? '$base${d.year}' : base;
}

const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// Kurzer Wochentag mit Datum, z. B. „Sa, 24.10.“.
String formatWeekdayDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${formatDate(d)}';

const _months = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Monat mit Jahr, z. B. „Oktober 2026“.
String formatMonth(DateTime d) => '${_months[d.month - 1]} ${d.year}';

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
