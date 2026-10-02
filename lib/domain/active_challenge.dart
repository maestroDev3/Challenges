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

/// Welche Regeln zur Art passen: „Hart“ nur mit Ziel zum Neustarten
/// (X Tage), einmalige Challenges haben keine Streak und keine Regel.
Set<StreakRule> allowedRules(ChallengeKind kind) => switch (kind) {
      DailyKind(days: _?) => const {
          StreakRule.relaxed,
          StreakRule.joker,
          StreakRule.strict,
        },
      OneTimeKind() => const {},
      _ => const {StreakRule.relaxed, StreakRule.joker},
    };

/// Die gewünschte Regel, falls sie passt, sonst „Locker“.
StreakRule ruleFor(ChallengeKind kind, StreakRule wanted) =>
    allowedRules(kind).contains(wanted) ? wanted : StreakRule.relaxed;

/// Einmalige Challenges haben keine Streak.
bool hasStreak(ChallengeKind kind) => kind is! OneTimeKind;

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

/// So weit im Voraus lässt sich ein Start planen.
const maxPlanDays = 90;

/// Höchstlänge je Teil des Wenn-Dann-Plans („Wann?“, „Wo?“).
const maxPlanLength = 60;

/// Markiert in [ActiveChallenge._copy] „Feld nicht ändern“.
const _keep = Object();

/// Einmalige Challenges mit festem Datum haben kein eigenes Startdatum.
bool canPlanStart(ChallengeKind kind) =>
    kind is! OneTimeKind || kind.date == null;

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
    this.stepLog = const {},
    this.windowStartedAt,
    this.sessionStartedAt,
    this.activityLog = const {},
    this.planWhen,
    this.planWhere,
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

  /// Abgehakte Schritte je Tag (nur bei Vorlagen mit Schritten).
  final Map<DateTime, Set<int>> stepLog;

  /// Startzeitpunkt des Zeitfensters bei einmaligen Challenges (z. B. 24 h
  /// fasten); null, solange nicht gestartet.
  final DateTime? windowStartedAt;

  /// Start der laufenden Aktivität („Ich bin gerade dabei“) oder null.
  final DateTime? sessionStartedAt;

  /// Mit dem Timer erfasste Minuten je Tag.
  final Map<DateTime, int> activityLog;

  /// Wenn-Dann-Plan: wann genau (Auslöser, z. B. „Nach dem Aufstehen“).
  final String? planWhen;

  /// Wenn-Dann-Plan: wo genau (z. B. „im Bad“).
  final String? planWhere;

  /// Der Plan als ein Satz („Nach dem Aufstehen, im Bad“) oder null.
  String? get plan {
    final parts = [?planWhen, ?planWhere];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Setzt den Wenn-Dann-Plan neu; leere Teile entfallen. Mehr als
  /// [maxPlanLength] Zeichen je Teil: [ArgumentError].
  ActiveChallenge withPlan({String? when, String? where}) {
    String? clean(String? s, String name) {
      final v = s?.trim() ?? '';
      if (v.length > maxPlanLength) {
        throw ArgumentError.value(s, name, 'höchstens $maxPlanLength Zeichen');
      }
      return v.isEmpty ? null : v;
    }

    return _copy(planWhen: clean(when, 'when'), planWhere: clean(where, 'where'));
  }

  ChallengeKind get kind => template.kind;

  bool get isArchived => status != ChallengeStatus.active;

  /// Geplant: der Starttag liegt nach [today]. Kein eigener Status – am
  /// Starttag ist die Challenge ohne Umschalten aktiv.
  bool isUpcoming(DateTime today) => dayOf(startedOn).isAfter(dayOf(today));

  /// Tage bis zum Start (0, sobald sie läuft).
  int daysUntilStart(DateTime today) {
    final days = dayOf(startedOn).difference(dayOf(today)).inDays;
    return days > 0 ? days : 0;
  }

  /// Beginnt eine geplante Challenge sofort.
  ActiveChallenge startNow(DateTime today) => copyWith(startedOn: dayOf(today));

  /// Verschiebt den Start auf [day] (heute bis [maxPlanDays] voraus).
  ActiveChallenge withStart(DateTime day, {required DateTime today}) {
    final days = dayOf(day).difference(dayOf(today)).inDays;
    if (days < 0 || days > maxPlanDays) {
      throw ArgumentError.value(day, 'day', 'heute bis $maxPlanDays Tage voraus');
    }
    return copyWith(startedOn: dayOf(day));
  }

  ActiveChallenge copyWith({
    DateTime? startedOn,
    ChallengeTemplate? template,
    ReminderTime? reminder,
    List<CheckIn>? checkIns,
    ChallengeStatus? status,
    DateTime? finishedOn,
    List<PauseRange>? pauses,
    StreakRule? rule,
    Map<DateTime, Set<int>>? stepLog,
    DateTime? windowStartedAt,
    bool clearWindow = false,
    DateTime? sessionStartedAt,
    bool clearSession = false,
    Map<DateTime, int>? activityLog,
    bool clearFinished = false,
  }) =>
      _copy(
        startedOn: startedOn,
        template: template,
        reminder: reminder,
        checkIns: checkIns,
        status: status,
        finishedOn: clearFinished ? null : finishedOn ?? this.finishedOn,
        pauses: pauses,
        rule: rule,
        stepLog: stepLog,
        windowStartedAt:
            clearWindow ? null : windowStartedAt ?? this.windowStartedAt,
        sessionStartedAt:
            clearSession ? null : sessionStartedAt ?? this.sessionStartedAt,
        activityLog: activityLog,
      );

  /// Kopie; nullable Felder werden immer übernommen wie übergeben.
  ActiveChallenge _copy({
    DateTime? startedOn,
    ChallengeTemplate? template,
    ReminderTime? reminder,
    List<CheckIn>? checkIns,
    ChallengeStatus? status,
    Object? finishedOn = _keep,
    List<PauseRange>? pauses,
    StreakRule? rule,
    Map<DateTime, Set<int>>? stepLog,
    Object? windowStartedAt = _keep,
    Object? sessionStartedAt = _keep,
    Map<DateTime, int>? activityLog,
    Object? planWhen = _keep,
    Object? planWhere = _keep,
  }) =>
      ActiveChallenge(
        id: id,
        template: template ?? this.template,
        startedOn: startedOn ?? this.startedOn,
        reminder: reminder ?? this.reminder,
        checkIns: checkIns ?? this.checkIns,
        status: status ?? this.status,
        finishedOn: identical(finishedOn, _keep)
            ? this.finishedOn
            : finishedOn as DateTime?,
        pauses: pauses ?? this.pauses,
        rule: rule ?? this.rule,
        stepLog: stepLog ?? this.stepLog,
        windowStartedAt: identical(windowStartedAt, _keep)
            ? this.windowStartedAt
            : windowStartedAt as DateTime?,
        sessionStartedAt: identical(sessionStartedAt, _keep)
            ? this.sessionStartedAt
            : sessionStartedAt as DateTime?,
        activityLog: activityLog ?? this.activityLog,
        planWhen:
            identical(planWhen, _keep) ? this.planWhen : planWhen as String?,
        planWhere:
            identical(planWhere, _keep) ? this.planWhere : planWhere as String?,
      );

  /// Startet den Aktivitäts-Timer; läuft schon einer, ändert sich nichts.
  ActiveChallenge startSession(DateTime now) =>
      isArchived || sessionStartedAt != null
          ? this
          : copyWith(sessionStartedAt: now);

  Duration? sessionElapsed(DateTime now) => switch (sessionStartedAt) {
        final start? => now.difference(start).isNegative
            ? Duration.zero
            : now.difference(start),
        null => null,
      };

  /// Zeitpunkt, an dem die Zieldauer erreicht ist (für das Signal).
  DateTime? get sessionTargetEnd => switch ((sessionStartedAt, template.targetDuration)) {
        (final start?, final target?) => start.add(target),
        _ => null,
      };

  int activityMinutesOn(DateTime day) => activityLog[dayOf(day)] ?? 0;

  /// Beendet den Timer und schreibt die Minuten gut: Wochenziel in Minuten
  /// addiert sie; mit Zieldauer ist der Tag erledigt, sobald sie erreicht
  /// ist; sonst zählt die Aktivität als erledigt.
  ActiveChallenge stopSession(DateTime now) {
    final start = sessionStartedAt;
    if (start == null) return this;
    final minutes = now.difference(start).inMinutes;
    final day = dayOf(start);
    final total = activityMinutesOn(day) + (minutes < 0 ? 0 : minutes);
    var c = copyWith(
      clearSession: true,
      activityLog: {...activityLog, day: total},
    );
    final target = template.targetDuration;
    if (kind case WeeklyGoalKind(unit: WeeklyUnit.minutes)) {
      if (minutes > 0) c = c.checkIn(day, CheckInStatus.done, minutes: minutes);
    } else if (target != null) {
      if (total >= target.inMinutes &&
          c.checkInOn(day)?.status != CheckInStatus.done) {
        c = c.checkIn(day, CheckInStatus.done);
      }
    } else if (minutes > 0) {
      c = c.checkIn(day, CheckInStatus.done);
    }
    return c;
  }

  Duration? get _window => switch (kind) {
        OneTimeKind(window: final w) => w,
        _ => null,
      };

  /// Startet das Zeitfenster jetzt (nur einmalige Challenges).
  ActiveChallenge startWindow(DateTime now) =>
      _window == null || isArchived ? this : copyWith(windowStartedAt: now);

  /// Bricht das Zeitfenster ab („nicht gestartet“).
  ActiveChallenge cancelWindow() => copyWith(clearWindow: true);

  DateTime? get windowEnd => switch ((windowStartedAt, _window)) {
        (final start?, final window?) => start.add(window),
        _ => null,
      };

  /// Verbleibende Zeit (nie negativ) oder null, wenn nicht gestartet.
  Duration? remaining(DateTime now) {
    final end = windowEnd;
    if (end == null) return null;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Anteil des verstrichenen Zeitfensters (0..1) oder null.
  double? windowProgress(DateTime now) {
    final start = windowStartedAt, window = _window;
    if (start == null || window == null) return null;
    final elapsed = now.difference(start).inSeconds / window.inSeconds;
    return elapsed.clamp(0.0, 1.0);
  }

  bool windowEnded(DateTime now) {
    final end = windowEnd;
    return end != null && !now.isBefore(end);
  }

  /// Archiviert die Challenge: „geschafft“, wenn das Ziel erreicht ist,
  /// sonst „beendet“.
  ActiveChallenge finish(DateTime now) => copyWith(
        status:
            isCompleted ? ChallengeStatus.completed : ChallengeStatus.ended,
        finishedOn: dayOf(now),
      );

  /// Holt eine archivierte Challenge mit ganzem Verlauf zurück.
  ActiveChallenge reopen() =>
      copyWith(status: ChallengeStatus.active, clearFinished: true);

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
    if (d.isBefore(dayOf(startedOn))) {
      throw StateError('Check-in vor dem Start der Challenge');
    }
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
    return copyWith(checkIns: updated, stepLog: _stepsFor(d, status));
  }

  /// Hält die Checkliste passend zum Tagesstatus: erledigt = alle Schritte,
  /// verpasst/leer = keine.
  Map<DateTime, Set<int>>? _stepsFor(DateTime d, CheckInStatus? status) {
    if (template.steps.isEmpty) return null;
    final log = {...stepLog};
    if (status == CheckInStatus.done) {
      log[d] = {for (var i = 0; i < template.steps.length; i++) i};
    } else {
      log.remove(d);
    }
    return log;
  }

  Set<int> stepsDoneOn(DateTime day) => stepLog[dayOf(day)] ?? const {};

  /// Hakt einen Schritt ab oder wieder ab. Sind alle Schritte erledigt, ist
  /// der Tag erledigt; sonst ist er offen.
  ActiveChallenge toggleStep(DateTime day, int index) {
    if (isArchived || index < 0 || index >= template.steps.length) return this;
    final d = dayOf(day);
    final done = {...stepsDoneOn(d)};
    if (!done.remove(index)) done.add(index);
    final complete = done.length == template.steps.length;
    final checkIns = [
      for (final c in this.checkIns)
        if (c.day != d) c,
      if (complete) CheckIn(day: d, status: CheckInStatus.done),
    ]..sort((a, b) => a.day.compareTo(b.day));
    return copyWith(checkIns: checkIns, stepLog: {...stepLog, d: done});
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
    return copyWith(checkIns: updated, stepLog: _stepsFor(d, status));
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
