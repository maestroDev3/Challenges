import 'challenge.dart';

/// Liefert die aktuelle Zeit. In Tests durch feste Werte ersetzbar.
typedef Clock = DateTime Function();

/// Normalisiert einen Zeitpunkt auf den Kalendertag (UTC, damit
/// Tagesdifferenzen nicht von Sommer-/Winterzeit abhängen).
DateTime dayOf(DateTime t) => DateTime.utc(t.year, t.month, t.day);

DateTime _weekStart(DateTime day) =>
    day.subtract(Duration(days: day.weekday - DateTime.monday));

enum CheckInStatus { done, missed }

enum DayStatus { done, missed, open }

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

class ActiveChallenge {
  const ActiveChallenge({
    required this.id,
    required this.template,
    required this.startedOn,
    required this.reminder,
    this.checkIns = const [],
    this.status = ChallengeStatus.active,
    this.finishedOn,
  });

  final String id;
  final ChallengeTemplate template;
  final DateTime startedOn;
  final ReminderTime reminder;
  final List<CheckIn> checkIns;
  final ChallengeStatus status;
  final DateTime? finishedOn;

  ChallengeKind get kind => template.kind;

  bool get isArchived => status != ChallengeStatus.active;

  ActiveChallenge copyWith({
    ChallengeTemplate? template,
    ReminderTime? reminder,
    List<CheckIn>? checkIns,
    ChallengeStatus? status,
    DateTime? finishedOn,
  }) =>
      ActiveChallenge(
        id: id,
        template: template ?? this.template,
        startedOn: startedOn,
        reminder: reminder ?? this.reminder,
        checkIns: checkIns ?? this.checkIns,
        status: status ?? this.status,
        finishedOn: finishedOn ?? this.finishedOn,
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

  int currentStreak(DateTime today) {
    final t = dayOf(today);
    if (kind is WeeklyGoalKind) {
      var week = _weekStart(t);
      if (!_weekGoalMet(week)) week = week.subtract(const Duration(days: 7));
      var n = 0;
      while (!week.isBefore(_weekStart(dayOf(startedOn))) &&
          _weekGoalMet(week)) {
        n++;
        week = week.subtract(const Duration(days: 7));
      }
      return n;
    }
    var d = checkInOn(t) == null ? t.subtract(const Duration(days: 1)) : t;
    var n = 0;
    while (checkInOn(d)?.status == CheckInStatus.done) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  int get bestStreak {
    if (kind is WeeklyGoalKind) {
      if (checkIns.isEmpty) return 0;
      var week = _weekStart(checkIns.first.day);
      final last = _weekStart(checkIns.last.day);
      var best = 0, run = 0;
      while (!week.isAfter(last)) {
        run = _weekGoalMet(week) ? run + 1 : 0;
        if (run > best) best = run;
        week = week.add(const Duration(days: 7));
      }
      return best;
    }
    var best = 0, run = 0;
    DateTime? prev;
    for (final c in checkIns) {
      if (c.status != CheckInStatus.done) {
        run = 0;
        prev = null;
        continue;
      }
      final consecutive =
          prev != null && c.day.difference(prev).inDays == 1;
      run = consecutive ? run + 1 : 1;
      prev = c.day;
      if (run > best) best = run;
    }
    return best;
  }

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
        switch (checkInOn(t.subtract(Duration(days: i)))?.status) {
          CheckInStatus.done => DayStatus.done,
          CheckInStatus.missed => DayStatus.missed,
          null => DayStatus.open,
        },
    ];
  }
}
