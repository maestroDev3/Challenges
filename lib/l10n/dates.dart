import 'app_localizations.dart';

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
