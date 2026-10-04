import 'active_challenge.dart';
import 'challenge.dart';
import 'milestones.dart';

/// Montag (UTC-Mitternacht) der Woche, in der [day] liegt.
DateTime weekStartOf(DateTime day) {
  final d = dayOf(day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// Montag der Woche, die der Rückblick zeigt: sonntags die laufende Woche,
/// an allen anderen Tagen die vergangene.
DateTime reviewWeekFor(DateTime today) {
  final start = weekStartOf(today);
  return dayOf(today).weekday == DateTime.sunday
      ? start
      : start.subtract(const Duration(days: 7));
}

/// Ein Meilenstein, der in der betrachteten Woche erreicht wurde.
class WeekBadge {
  const WeekBadge({required this.challenge, required this.milestone});
  final ActiveChallenge challenge;
  final int milestone;
}

/// Wochenbilanz einer Challenge. Bei Wochenzielen sind [dueDays] das Ziel
/// und [doneDays] die erreichten Einheiten (höchstens das Ziel), damit eine
/// erfüllte Woche 100 % ergibt statt tageweise „verpasst“.
class WeekReviewEntry {
  const WeekReviewEntry({
    required this.challenge,
    required this.days,
    required this.dueDays,
    required this.doneDays,
    required this.jokerDays,
    required this.missedDays,
    required this.minutes,
    required this.weeklyGoalReached,
  });

  final ActiveChallenge challenge;

  /// Status Mo–So; vergangene fällige Tage ohne Eintrag gelten als verpasst.
  final List<DayStatus> days;
  final int dueDays;
  final int doneDays;
  final int jokerDays;
  final int missedDays;

  /// Erfasste Minuten (nur Wochenziele in Minuten).
  final int minutes;

  /// Nur bei Wochenzielen; sonst null.
  final bool? weeklyGoalReached;

  String get title => challenge.template.title;
}

/// Rückblick auf eine Kalenderwoche (Mo–So) über alle Challenges – die
/// Grundlage für die Sonntags-Benachrichtigung und das Statistik-Dashboard.
/// Einmalige Challenges haben keine Wochenbilanz und fehlen.
class WeekReview {
  const WeekReview._({
    required this.from,
    required this.until,
    required this.entries,
    required this.badges,
    required this.bestStreak,
  });

  factory WeekReview.of(
    List<ActiveChallenge> challenges, {
    required DateTime weekStart,
    required DateTime today,
  }) {
    final from = weekStartOf(weekStart);
    final until = from.add(const Duration(days: 6));
    final t = dayOf(today);
    final last = t.isBefore(until) ? t : until;

    final entries = <WeekReviewEntry>[];
    final badges = <WeekBadge>[];
    var bestStreak = 0;
    for (final c in challenges) {
      if (!_isInWeek(c, from, until)) continue;
      entries.add(_entry(c, from: from, last: last, today: t));
      if (c.kind is DailyKind || c.kind is JournalKind) {
        badges.addAll(_badgesIn(c, from: from, last: last));
        final streak = c.currentStreak(last);
        if (streak > bestStreak) bestStreak = streak;
      }
    }
    return WeekReview._(
      from: from,
      until: until,
      entries: entries,
      badges: badges,
      bestStreak: bestStreak,
    );
  }

  final DateTime from;
  final DateTime until;
  final List<WeekReviewEntry> entries;

  /// Meilensteine, deren Erreichungstag in der Woche liegt.
  final List<WeekBadge> badges;

  /// Höchste aktuelle Serie am Ende der Woche (bzw. heute).
  final int bestStreak;

  int get done => entries.fold(0, (sum, e) => sum + e.doneDays);
  int get due => entries.fold(0, (sum, e) => sum + e.dueDays);

  /// Erledigt / fällig oder null, wenn nichts fällig war.
  double? get rate => due == 0 ? null : done / due;

  int get totalMinutes => entries.fold(0, (sum, e) => sum + e.minutes);

  static bool _isInWeek(ActiveChallenge c, DateTime from, DateTime until) {
    if (c.kind is OneTimeKind) return false;
    if (dayOf(c.startedOn).isAfter(until)) return false;
    final finished = c.finishedOn;
    return finished == null || !dayOf(finished).isBefore(from);
  }

  static WeekReviewEntry _entry(
    ActiveChallenge c, {
    required DateTime from,
    required DateTime last,
    required DateTime today,
  }) {
    final start = dayOf(c.startedOn);
    final days = <DayStatus>[];
    var due = 0, done = 0, joker = 0, missed = 0;
    for (var i = 0; i < 7; i++) {
      final d = from.add(Duration(days: i));
      var status = c.statusOn(d, today: today);
      final isDue = !d.isBefore(start) && !d.isAfter(last) && !c.isPaused(d);
      if (isDue && status == DayStatus.open && d.isBefore(today)) {
        status = DayStatus.missed;
      }
      days.add(status);
      if (c.kind is WeeklyGoalKind || !isDue) continue;
      due++;
      switch (status) {
        case DayStatus.done:
          done++;
        case DayStatus.joker:
          joker++;
        case DayStatus.missed:
          missed++;
        case DayStatus.open:
        case DayStatus.paused:
          break;
      }
    }

    var minutes = 0;
    bool? reached;
    if (c.kind case WeeklyGoalKind(target: final target, unit: final unit)) {
      final value = c.weekValue(from);
      due = target;
      done = value > target ? target : value;
      reached = value >= target;
      if (unit == WeeklyUnit.minutes) minutes = c.minutesInWeek(from);
    }

    return WeekReviewEntry(
      challenge: c,
      days: days,
      dueDays: due,
      doneDays: done,
      jokerDays: joker,
      missedDays: missed,
      minutes: minutes,
      weeklyGoalReached: reached,
    );
  }

  /// Meilensteine, die an einem Tag der Woche (bis [last]) erreicht wurden:
  /// die Serie am Tag ist mindestens so lang, am Vortag noch nicht.
  static Iterable<WeekBadge> _badgesIn(
    ActiveChallenge c, {
    required DateTime from,
    required DateTime last,
  }) sync* {
    for (var d = from; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      if (d.isBefore(dayOf(c.startedOn))) continue;
      final before = c.currentStreak(d.subtract(const Duration(days: 1)));
      final now = c.currentStreak(d);
      for (final m in milestones) {
        if (before < m && now >= m) {
          yield WeekBadge(challenge: c, milestone: m);
        }
      }
    }
  }
}
