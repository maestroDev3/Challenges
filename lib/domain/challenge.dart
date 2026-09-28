import 'dart:math';

/// Art einer Challenge – bestimmt, wie Fortschritt und Streak berechnet werden.
sealed class ChallengeKind {
  const ChallengeKind();
}

/// Jeden Tag abhaken. [days] == null bedeutet: ohne Enddatum.
class DailyKind extends ChallengeKind {
  const DailyKind({this.days});
  final int? days;
}

/// Einmal innerhalb eines Zeitfensters schaffen (z. B. 24 h fasten),
/// optional an einem festen Datum.
class OneTimeKind extends ChallengeKind {
  const OneTimeKind(this.window, {this.date});
  final Duration window;
  final DateTime? date;
}

enum WeeklyUnit { minutes, times }

/// Pro Woche ein Ziel erreichen: [target] Minuten oder [target]-mal.
class WeeklyGoalKind extends ChallengeKind {
  const WeeklyGoalKind(this.target, {this.unit = WeeklyUnit.minutes});
  final int target;
  final WeeklyUnit unit;

  /// Zielminuten (nur sinnvoll bei [WeeklyUnit.minutes]).
  int get minutes => target;
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
    this.steps = const [],
    this.targetDuration,
  });

  /// Eigene Challenge des Nutzers. Wirft [ArgumentError] bei ungültigen Werten.
  factory ChallengeTemplate.custom({
    required String title,
    required ChallengeKind kind,
    String emoji = '⭐',
    String description = '',
    String? id,
    List<String> steps = const [],
    Duration? targetDuration,
  }) {
    final t = title.trim();
    if (t.isEmpty) throw ArgumentError.value(title, 'title', 'darf nicht leer sein');
    switch (kind) {
      case DailyKind(days: final d?) when d < 1 || d > 365:
        throw ArgumentError.value(d, 'days', '1–365');
      case WeeklyGoalKind(unit: WeeklyUnit.times, target: final n)
          when n < 1 || n > 7:
        throw ArgumentError.value(n, 'target', '1–7 mal pro Woche');
      case WeeklyGoalKind(unit: WeeklyUnit.minutes, target: final n)
          when n < 1 || n > 10080:
        throw ArgumentError.value(n, 'target', '1–10080 Minuten pro Woche');
      default:
        break;
    }
    return ChallengeTemplate(
      id: id ?? '$customPrefix${_randomId()}',
      title: t,
      description: description.trim(),
      emoji: emoji.isEmpty ? '⭐' : emoji,
      kind: kind,
      steps: [
        for (final s in steps)
          if (s.trim().isNotEmpty) s.trim(),
      ],
      targetDuration: targetDuration == null || targetDuration <= Duration.zero
          ? null
          : targetDuration,
    );
  }

  static const customPrefix = 'custom-';
  static final _random = Random.secure();
  static String _randomId() => List.generate(
      10, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)]).join();

  final String id;
  final String title;
  final String description;
  final String emoji;
  final ChallengeKind kind;

  /// Optionale Schritte (Checkliste); der Tag ist erledigt, wenn alle
  /// Schritte abgehakt sind.
  final List<String> steps;

  /// Optionale Zieldauer pro Tag (z. B. 10 min meditieren) für den Timer.
  final Duration? targetDuration;

  /// Hat einen Aktivitäts-Timer („Ich bin gerade dabei“).
  bool get isTimed => targetDuration != null || kind is WeeklyGoalKind;

  bool get isCustom => id.startsWith(customPrefix);

  ChallengeTemplate copyWith({
    String? title,
    String? description,
    String? emoji,
    ChallengeKind? kind,
    List<String>? steps,
    Duration? targetDuration,
  }) =>
      ChallengeTemplate.custom(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        emoji: emoji ?? this.emoji,
        kind: kind ?? this.kind,
        steps: steps ?? this.steps,
        targetDuration: targetDuration ?? this.targetDuration,
      );

  /// Kurzes Label für Chips, z. B. „30 Tage“, „24 h“, „2 h/Woche“.
  String get kindLabel => switch (kind) {
        DailyKind(days: final d?) => '$d Tage',
        DailyKind() => 'täglich',
        OneTimeKind(date: final d?) =>
          'einmalig · ${_two(d.day)}.${_two(d.month)}.',
        OneTimeKind(window: final w) => '${w.inHours} h',
        WeeklyGoalKind(unit: WeeklyUnit.times, target: final n) => '$n×/Woche',
        WeeklyGoalKind(target: final m) =>
          m % 60 == 0 ? '${m ~/ 60} h/Woche' : '$m min/Woche',
        JournalKind() => 'Journal',
      };
}

String _two(int n) => n.toString().padLeft(2, '0');
