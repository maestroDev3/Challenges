import 'active_challenge.dart';
import 'challenge.dart';
import 'challenge_repository.dart';

/// Texte der Tabelle; die UI übergibt sie in der gewählten Sprache.
class CsvTexts {
  const CsvTexts({
    required this.header,
    required this.done,
    required this.missed,
    this.title = _storedTitle,
  });

  /// Kopfzeile mit `;` als Trenner.
  final String header;
  final String done;
  final String missed;

  /// Anzeigename einer Vorlage (Katalog-Vorlagen übersetzt).
  final String Function(ChallengeTemplate template) title;

  static const german = CsvTexts(
    header: 'Datum;Challenge;Status;Minuten;Notiz',
    done: 'erledigt',
    missed: 'nicht erledigt',
  );

  static String _storedTitle(ChallengeTemplate template) => template.title;
}

/// Tabelle aller Check-ins zum Ansehen in Excel oder Google Sheets.
///
/// Trenner `;` und UTF-8-BOM, damit ein deutsches Excel die Datei direkt
/// richtig öffnet; Zeilenende `\r\n` nach RFC 4180.
String exportCsv(ChallengeStore store, {CsvTexts texts = CsvTexts.german}) {
  final rows = <(DateTime, String, CheckIn)>[
    for (final c in [...store.active, ...store.archived])
      for (final ci in c.checkIns) (ci.day, texts.title(c.template), ci),
  ]..sort((a, b) {
      final byDay = a.$1.compareTo(b.$1);
      return byDay != 0 ? byDay : a.$2.compareTo(b.$2);
    });
  final buffer = StringBuffer('﻿')
    ..write('${texts.header}\r\n');
  for (final (day, title, ci) in rows) {
    buffer
      ..writeAll([
        _date(day),
        _field(title),
        switch (ci.status) {
          CheckInStatus.done => texts.done,
          CheckInStatus.missed => texts.missed,
        },
        ci.minutes?.toString() ?? '',
        _field(ci.note ?? ''),
      ], ';')
      ..write('\r\n');
  }
  return buffer.toString();
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String _two(int n) => n.toString().padLeft(2, '0');

String _field(String value) {
  if (!value.contains(RegExp('[;"\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}
