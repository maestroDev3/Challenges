import 'challenge.dart';

/// Liefert die aktuelle Zeit. In Tests durch feste Werte ersetzbar.
typedef Clock = DateTime Function();

/// Normalisiert einen Zeitpunkt auf den Kalendertag (UTC, damit
/// Tagesdifferenzen nicht von Sommer-/Winterzeit abhängen).
DateTime dayOf(DateTime t) => DateTime.utc(t.year, t.month, t.day);

DateTime _weekStart(DateTime day) =>
    day.subtract(Duration(days: day.weekday - DateTime.monday));

enum CheckInStatus { done, missed }

/// Status eines Tages für Wochenleiste und Kalender.
/// [joker]: verpasst, aber von einem Joker gerettet.
enum DayStatus { done, missed, open, paused, joker }

enum ChallengeStatus { active, completed, ended }

/// Umgang mit Fehltagen.
/// - [relaxed]: Fehltag setzt nur die Streak auf 0.
/// - [joker]: pro 7 erledigten Einheiten am Stück ein Joker (max. 2), der
///   einen Fehltag abfängt (Streak bleibt, Tag zählt nicht).
/// - [strict]: Fehltag startet einen neuen Versuch bei Tag 1.
enum StreakRule { relaxed, joker, strict }

const _jokerEvery = 7;
const _maxJokers = 2;

typedef _Evaluation = ({
  int current,
  int best,
  int jokers,
  int attempt,
  int attemptDone,
  List<DateTime> jokerDays,
});

class ReminderTime {
  const ReminderTime(this.hour, this.minute);
  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class CheckIn {
  CheckIn({
    required DateTime day,
    required this.status,
    this.minutes,
    this.note,
  }) : day = dayOf(day);

  final DateTime day;
  final CheckInStatus status;
  final int? minutes;
  final String? note;
}

/// Pausenzeitraum (inklusive beider Tage).
class PauseRange {
  PauseRange({required DateTime from, required DateTime until})
      : from = dayOf(from),
        until = dayOf(until);

  final DateTime from;
  final DateTime until;

  bool contains(DateTime day) {
    final d = dayOf(day);
    return !d.isBefore(from) && !d.isAfter(until);
  }
}

class ActiveChallenge {
  const ActiveChallenge({
    required this.id,
    required this.template,
    required this.startedOn,
    required this.reminder,
    this.checkIns = const [],
    this.status = ChallengeStatus.active,
    this.finishedOn,
    this.pauses = const [],
    this.rule = StreakRule.relaxed,
  });

  final String id;
  final ChallengeTemplate template;
  final DateTime startedOn;
  final ReminderTime reminder;
  final List<CheckIn> checkIns;
  final ChallengeStatus status;
  final DateTime? finishedOn;
  final List<PauseRange> pauses;
  final StreakRule rule;

  ChallengeKind get kind => template.kind;

  bool get isArchived => status != ChallengeStatus.active;

  ActiveChallenge copyWith({
    ChallengeTemplate? template,
    ReminderTime? reminder,
    List<CheckIn>? checkIns,
    ChallengeStatus? status,
    DateTime? finishedOn,
    List<PauseRange>? pauses,
    StreakRule? rule,
  }) =>
      ActiveChallenge(
        id: id,
        template: template ?? this.template,
        startedOn: startedOn,
        reminder: reminder ?? this.reminder,
        checkIns: checkIns ?? this.checkIns,
        status: status ?? this.status,
        finishedOn: finishedOn ?? this.finishedOn,
        pauses: pauses ?? this.pauses,
        rule: rule ?? this.rule,
      );

  /// Archiviert die Challenge: „geschafft“, wenn das Ziel erreicht ist,
  /// sonst „beendet“.
  ActiveChallenge finish(DateTime now) => copyWith(
        status:
            isCompleted ? ChallengeStatus.completed : ChallengeStatus.ended,
        finishedOn: dayOf(now),
      );

  /// True, wenn das Ziel erreicht ist und die Challenge automatisch ins
  /// Archiv wandern soll (X Tage oder einmalig).
  bool shouldAutoFinish(DateTime today) =>
      !isArchived &&
      isCompleted &&
      switch (kind) {
        DailyKind(days: _?) || OneTimeKind() => true,
        _ => false,
      };

  CheckIn? checkInOn(DateTime day) {
    final d = dayOf(day);
    for (final c in checkIns) {
      if (c.day == d) return c;
    }
    return null;
  }

  /// Trägt den Tagesstatus ein. Ein Eintrag pro Tag; beim Wochenziel
  /// werden Minuten am selben Tag aufsummiert.
  ActiveChallenge checkIn(
    DateTime day,
    CheckInStatus status, {
    int? minutes,
    String? note,
  }) {
    if (isArchived) return this;
    final d = dayOf(day);
    final existing = checkInOn(d);
    var total = minutes;
    if (kind case WeeklyGoalKind(unit: WeeklyUnit.minutes)
        when existing != null &&
        status == CheckInStatus.done &&
        existing.status == CheckInStatus.done) {
      total = (existing.minutes ?? 0) + (minutes ?? 0);
    }
    final updated = [
      for (final c in checkIns)
        if (c.day != d) c,
      CheckIn(day: d, status: status, minutes: total, note: note),
    ]..sort((a, b) => a.day.compareTo(b.day));
    return copyWith(checkIns: updated);
  }

  int get doneDays =>
      checkIns.where((c) => c.status == CheckInStatus.done).length;

  int minutesInWeek(DateTime today) {
    final start = _weekStart(dayOf(today));
    final end = start.add(const Duration(days: 7));
    return checkIns
        .where((c) =>
            c.status == CheckInStatus.done &&
            !c.day.isBefore(start) &&
            c.day.isBefore(end))
        .fold(0, (sum, c) => sum + (c.minutes ?? 0));
  }

  /// Anzahl erledigter Tage in der Woche von [today] (Mo–So).
  int doneDaysInWeek(DateTime today) {
    final start = _weekStart(dayOf(today));
    final end = start.add(const Duration(days: 7));
    return checkIns
        .where((c) =>
            c.status == CheckInStatus.done &&
            !c.day.isBefore(start) &&
            c.day.isBefore(end))
        .length;
  }

  /// Erreichter Wert in der Woche: Minuten oder Anzahl Tage je nach Einheit.
  int weekValue(DateTime today) => switch (kind) {
        WeeklyGoalKind(unit: WeeklyUnit.times) => doneDaysInWeek(today),
        _ => minutesInWeek(today),
      };

  bool _weekGoalMet(DateTime anyDayInWeek) =>
      weekValue(anyDayInWeek) >= (kind as WeeklyGoalKind).target;

  /// Trägt einen Tag der letzten 7 Tage nach, ändert oder entfernt ihn
  /// ([status] == null). Wirft [ArgumentError] für Tage in der Zukunft,
  /// vor dem Start oder älter als 7 Tage.
  ActiveChallenge correct(
    DateTime day,
    CheckInStatus? status, {
    required DateTime today,
    int? minutes,
    String? note,
  }) {
    final d = dayOf(day);
    final t = dayOf(today);
    if (d.isAfter(t) ||
        d.isBefore(dayOf(startedOn)) ||
        t.difference(d).inDays > 6) {
      throw ArgumentError.value(day, 'day', 'nur die letzten 7 Tage seit Start');
    }
    if (isArchived) return this;
    final updated = [
      for (final c in checkIns)
        if (c.day != d) c,
      if (status != null)
        CheckIn(day: d, status: status, minutes: minutes, note: note),
    ]..sort((a, b) => a.day.compareTo(b.day));
    return copyWith(checkIns: updated);
  }

  /// Pausiert die Challenge von [from] bis einschließlich [until].
  ActiveChallenge pause({required DateTime from, required DateTime until}) {
    if (dayOf(until).isBefore(dayOf(from))) {
      throw ArgumentError.value(until, 'until', 'liegt vor dem Beginn');
    }
    return copyWith(pauses: [...pauses, PauseRange(from: from, until: until)]);
  }

  /// Beendet laufende und künftige Pausen ab [today].
  ActiveChallenge resume(DateTime today) {
    final t = dayOf(today);
    final yesterday = t.subtract(const Duration(days: 1));
    return copyWith(pauses: [
      for (final p in pauses)
        if (p.from.isBefore(t))
          p.until.isBefore(t) ? p : PauseRange(from: p.from, until: yesterday),
    ]);
  }

  bool isPaused(DateTime day) => pauses.any((p) => p.contains(day));

  /// Letzter Pausentag, falls [today] pausiert ist.
  DateTime? pausedUntil(DateTime today) {
    for (final p in pauses) {
      if (p.contains(today)) return p.until;
    }
    return null;
  }

  int currentStreak(DateTime today) => _evaluate(today).current;

  int get bestStreak => _evaluate(_lastDay).best;

  /// Verfügbare Joker (nur bei [StreakRule.joker]).
  int jokers(DateTime today) => _evaluate(today).jokers;

  /// Tage (bzw. Wochenanfänge), die ein Joker gerettet hat.
  List<DateTime> jokerDays(DateTime today) => _evaluate(today).jokerDays;

  /// Aktueller Versuch (nur bei [StreakRule.strict] größer als 1).
  int attempt(DateTime today) => _evaluate(today).attempt;

  DateTime get _firstDay {
    var first = dayOf(startedOn);
    for (final c in checkIns) {
      if (c.day.isBefore(first)) first = c.day;
    }
    return first;
  }

  DateTime get _lastDay {
    var last = _firstDay;
    for (final c in checkIns) {
      if (c.day.isAfter(last)) last = c.day;
    }
    return last;
  }

  /// Geht alle Tage (bzw. Wochen) vom Start bis [today] durch und wendet
  /// die [rule] an. Pausierte Tage sind neutral; ein offener heutiger Tag
  /// (bzw. die laufende Woche) zählt noch nicht als Fehltag.
  _Evaluation _evaluate(DateTime today) {
    final t = dayOf(today);
    if (kind is OneTimeKind) {
      final n = doneDays > 0 ? 1 : 0;
      return (
        current: n,
        best: n,
        jokers: 0,
        attempt: 1,
        attemptDone: n,
        jokerDays: const <DateTime>[],
      );
    }
    final weekly = kind is WeeklyGoalKind;
    final step = Duration(days: weekly ? 7 : 1);
    final end = weekly ? _weekStart(t) : t;
    final byDay = {for (final c in checkIns) c.day: c.status};

    var streak = 0, best = 0, run = 0, jokers = 0, attempt = 1, attemptDone = 0;
    final jokerDays = <DateTime>[];
    for (var u = weekly ? _weekStart(_firstDay) : _firstDay;
        !u.isAfter(end);
        u = u.add(step)) {
      final bool done;
      final bool failed;
      if (weekly) {
        done = _weekGoalMet(u);
        failed = !done && u != end && !_weekHasPause(u);
      } else {
        if (isPaused(u)) continue;
        final status = byDay[u];
        done = status == CheckInStatus.done;
        failed = status == CheckInStatus.missed || (status == null && u != end);
      }
      if (done) {
        streak++;
        run++;
        attemptDone++;
        if (streak > best) best = streak;
        if (rule == StreakRule.joker &&
            run % _jokerEvery == 0 &&
            jokers < _maxJokers) {
          jokers++;
        }
      } else if (failed) {
        if (rule == StreakRule.joker && jokers > 0) {
          jokers--;
          jokerDays.add(u);
        } else {
          streak = 0;
          run = 0;
          // Neuer Versuch nur, wenn der aktuelle schon Fortschritt hatte.
          if (rule == StreakRule.strict && attemptDone > 0) {
            attempt++;
            attemptDone = 0;
          }
        }
      }
    }
    return (
      current: streak,
      best: best,
      jokers: jokers,
      attempt: attempt,
      attemptDone: attemptDone,
      jokerDays: jokerDays,
    );
  }

  bool _weekHasPause(DateTime weekStart) => List.generate(
          7, (i) => weekStart.add(Duration(days: i)))
      .any(isPaused);

  /// Fortschritt 0..1 oder null, wenn die Challenge kein Ende hat.
  double? progress(DateTime today) => switch (kind) {
        DailyKind(days: final days?) =>
          (_countedDays(today) / days).clamp(0.0, 1.0),
        DailyKind() => null,
        OneTimeKind() => doneDays > 0 ? 1.0 : 0.0,
        WeeklyGoalKind(target: final goal) =>
          (weekValue(today) / goal).clamp(0.0, 1.0),
        JournalKind() => null,
      };

  bool get isCompleted => switch (kind) {
        DailyKind(days: final days?) => _countedDays(_lastDay) >= days,
        OneTimeKind() => doneDays > 0,
        _ => false,
      };

  /// Erledigte Tage, die zum Ziel zählen: bei [StreakRule.strict] nur im
  /// aktuellen Versuch, sonst alle.
  int _countedDays(DateTime today) => rule == StreakRule.strict
      ? _evaluate(today).attemptDone
      : doneDays;

  /// Status der letzten 7 Tage, ältester zuerst.
  List<DayStatus> week(DateTime today) {
    final t = dayOf(today);
    final saved = _jokerSet(t);
    return [
      for (var i = 6; i >= 0; i--)
        _dayStatus(t.subtract(Duration(days: i)), saved),
    ];
  }

  /// Status eines beliebigen Tages (für den Kalender).
  DayStatus statusOn(DateTime day, {required DateTime today}) =>
      _dayStatus(dayOf(day), _jokerSet(dayOf(today)));

  Set<DateTime> _jokerSet(DateTime today) =>
      kind is WeeklyGoalKind ? const {} : jokerDays(today).toSet();

  DayStatus _dayStatus(DateTime day, Set<DateTime> saved) {
    if (saved.contains(day)) return DayStatus.joker;
    return switch (checkInOn(day)?.status) {
      CheckInStatus.done => DayStatus.done,
      CheckInStatus.missed => DayStatus.missed,
      null => isPaused(day) ? DayStatus.paused : DayStatus.open,
    };
  }

  /// Anteil erledigter an fälligen Tagen (bzw. erreichter an vergangenen
  /// Wochen). Pausen zählen nicht; heute zählt erst mit Eintrag. Null ohne
  /// fällige Tage oder bei einmaligen Challenges.
  double? successRate(DateTime today) {
    final t = dayOf(today);
    if (kind is OneTimeKind) return null;
    if (kind is WeeklyGoalKind) {
      var met = 0, due = 0;
      final current = _weekStart(t);
      for (var w = _weekStart(_firstDay);
          w.isBefore(current);
          w = w.add(const Duration(days: 7))) {
        if (_weekHasPause(w) && !_weekGoalMet(w)) continue;
        due++;
        if (_weekGoalMet(w)) met++;
      }
      return due == 0 ? null : met / due;
    }
    var done = 0, due = 0;
    for (var d = _firstDay; !d.isAfter(t); d = d.add(const Duration(days: 1))) {
      if (isPaused(d)) continue;
      final status = checkInOn(d)?.status;
      if (d == t && status == null) continue;
      due++;
      if (status == CheckInStatus.done) done++;
    }
    return due == 0 ? null : done / due;
  }

  /// Journal-Einträge mit Text, neueste zuerst.
  List<CheckIn> get journalEntries => [
        for (final c in checkIns.reversed)
          if (c.note case final n? when n.trim().isNotEmpty) c,
      ];
}
