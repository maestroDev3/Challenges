/// Art einer Challenge – bestimmt, wie Fortschritt und Streak berechnet werden.
sealed class ChallengeKind {
  const ChallengeKind();
}

/// Jeden Tag abhaken. [days] == null bedeutet: ohne Enddatum.
class DailyKind extends ChallengeKind {
  const DailyKind({this.days});
  final int? days;
}

/// Einmal innerhalb eines Zeitfensters schaffen (z. B. 24 h fasten).
class OneTimeKind extends ChallengeKind {
  const OneTimeKind(this.window);
  final Duration window;
}

/// Pro Woche eine Anzahl Minuten sammeln.
class WeeklyGoalKind extends ChallengeKind {
  const WeeklyGoalKind(this.minutes);
  final int minutes;
}

/// Täglicher Eintrag mit Text (z. B. Ausreden aufschreiben).
class JournalKind extends ChallengeKind {
  const JournalKind();
}

class ChallengeTemplate {
  const ChallengeTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.kind,
  });

  final String id;
  final String title;
  final String description;
  final String emoji;
  final ChallengeKind kind;

  /// Kurzes Label für Chips, z. B. „30 Tage“, „24 h“, „2 h/Woche“.
  String get kindLabel => switch (kind) {
        DailyKind(days: final d?) => '$d Tage',
        DailyKind() => 'täglich',
        OneTimeKind(window: final w) => '${w.inHours} h',
        WeeklyGoalKind(minutes: final m) =>
          m % 60 == 0 ? '${m ~/ 60} h/Woche' : '$m min/Woche',
        JournalKind() => 'Journal',
      };
}
