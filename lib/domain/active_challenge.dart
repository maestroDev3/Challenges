import 'challenge.dart';

/// Liefert die aktuelle Zeit. In Tests durch feste Werte ersetzbar.
typedef Clock = DateTime Function();

/// Normalisiert einen Zeitpunkt auf den Kalendertag (UTC, damit
/// Tagesdifferenzen nicht von Sommer-/Winterzeit abhängen).
DateTime dayOf(DateTime t) => DateTime.utc(t.year, t.month, t.day);

DateTime _weekStart(DateTime day) =>
    day.subtract(Duration(days: day.weekday - DateTime.monday));

enum CheckInStatus { done, missed }

enum DayStatus { done, missed, open, paused }

enum ChallengeStatus { active, completed, ended }

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
  });

  final String id;
  final ChallengeTemplate template;
  final DateTime startedOn;
  final ReminderTime reminder;
  final List<CheckIn> checkIns;
  final ChallengeStatus status;
  final DateTime? finishedOn;
  final List<PauseRange> pauses;

  ChallengeKind get kind => template.kind;

  bool get isArchived => status != ChallengeStatus.active;

  ActiveChallenge copyWith({
    ChallengeTemplate? template,
    ReminderTime? reminder,
    List<CheckIn>? checkIns,
    ChallengeStatus? status,
    DateTime? finishedOn,
    List<PauseRange>? pauses,
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

  int currentStreak(DateTime today) => _streaks(today).current;

  int get bestStreak => _streaks(_lastDay).best;

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

  /// Geht alle Tage (bzw. Wochen) vom Start bis [today] durch.
  /// Pausierte Tage sind neutral; ein offener heutiger Tag (bzw. die
  /// laufende Woche) bricht die Streak noch nicht.
  ({int current, int best}) _streaks(DateTime today) {
    final t = dayOf(today);
    if (kind is OneTimeKind) {
      final n = isCompleted ? 1 : 0;
      return (current: n, best: n);
    }
    if (kind is WeeklyGoalKind) return _weekStreaks(t);
    final byDay = {for (final c in checkIns) c.day: c.status};
    var streak = 0, best = 0;
    for (var d = _firstDay;
        !d.isAfter(t);
        d = d.add(const Duration(days: 1))) {
      if (isPaused(d)) continue;
      final status = byDay[d];
      if (status == CheckInStatus.done) {
        streak++;
        if (streak > best) best = streak;
      } else if (status == CheckInStatus.missed || d.isBefore(t)) {
        streak = 0;
      }
    }
    return (current: streak, best: best);
  }

  ({int current, int best}) _weekStreaks(DateTime today) {
    final current = _weekStart(today);
    var streak = 0, best = 0;
    for (var w = _weekStart(_firstDay);
        !w.isAfter(current);
        w = w.add(const Duration(days: 7))) {
      if (_weekGoalMet(w)) {
        streak++;
        if (streak > best) best = streak;
      } else if (w != current && !_weekHasPause(w)) {
        streak = 0;
      }
    }
    return (current: streak, best: best);
  }

  bool _weekHasPause(DateTime weekStart) => List.generate(
          7, (i) => weekStart.add(Duration(days: i)))
      .any(isPaused);

  /// Fortschritt 0..1 oder null, wenn die Challenge kein Ende hat.
  double? progress(DateTime today) => switch (kind) {
        DailyKind(days: final days?) => (doneDays / days).clamp(0.0, 1.0),
        DailyKind() => null,
        OneTimeKind() => doneDays > 0 ? 1.0 : 0.0,
        WeeklyGoalKind(target: final goal) =>
          (weekValue(today) / goal).clamp(0.0, 1.0),
        JournalKind() => null,
      };

  bool get isCompleted => switch (kind) {
        DailyKind(days: final days?) => doneDays >= days,
        OneTimeKind() => doneDays > 0,
        _ => false,
      };

  /// Status der letzten 7 Tage, ältester zuerst.
  List<DayStatus> week(DateTime today) {
    final t = dayOf(today);
    return [
      for (var i = 6; i >= 0; i--)
        _dayStatus(t.subtract(Duration(days: i))),
    ];
  }

  DayStatus _dayStatus(DateTime day) =>
      switch (checkInOn(day)?.status) {
        CheckInStatus.done => DayStatus.done,
        CheckInStatus.missed => DayStatus.missed,
        null => isPaused(day) ? DayStatus.paused : DayStatus.open,
      };
}
