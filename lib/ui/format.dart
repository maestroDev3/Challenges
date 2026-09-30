export '../l10n/dates.dart';

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
