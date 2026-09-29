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
