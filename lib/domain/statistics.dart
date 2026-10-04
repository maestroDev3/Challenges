import 'active_challenge.dart';
import 'challenge.dart';
import 'milestones.dart' as milestones;
import 'week_review.dart';

/// Zeitraum für Kopfzahlen und Zeit-Summen: laufender Kalendermonat oder
/// laufendes Kalenderjahr.
enum StatsPeriod { month, year }

/// Mindest- und Höchstzahl Wochen für Heatmap und Wochenquoten.
const minStatsWeeks = 13;
const maxStatsWeeks = 52;

/// Eine laufende Challenge im Abschnitt „Pro Ritual“.
class ChallengeStat {
  const ChallengeStat({
    required this.challenge,
    required this.currentStreak,
    required this.rate,
    required this.progress,
  });

  final ActiveChallenge challenge;
  final int currentStreak;
  final double? rate;
  final double? progress;
}

/// Ein Abzeichen mit der Challenge, die es verdient hat.
class BadgeStat {
  const BadgeStat({required this.challenge, required this.milestone});
  final ActiveChallenge challenge;
  final int milestone;
}

/// Minuten einer Wochenziel-Challenge im Zeitraum.
class MinutesStat {
  const MinutesStat({required this.challenge, required this.minutes});
  final ActiveChallenge challenge;
  final int minutes;
}

/// Kennzahlen über alle Challenges für den Tab „Statistik“. Reine
/// Auswertung vorhandener Daten; Zeit kommt nur über [today].
///
/// Quote: tägliche und Journal-Challenges zählen in Tagen (heute nur mit
/// Eintrag), Wochenziele in Einheiten je Woche (höchstens das Ziel), damit
/// eine erfüllte Woche 100 % ergibt. Einmalige Challenges zählen nicht.
class Statistics {
  const Statistics._({
    required this.from,
    required this.until,
    required this.daysDone,
    required this.done,
    required this.due,
    required this.longestStreak,
    required this.longestStreakChallenge,
    required this.active,
    required this.completed,
    required this.heatmapStart,
    required this.heatmap,
    required this.weeks,
    required this.weekdays,
    required this.minutesByChallenge,
    required this.perChallenge,
    required this.badges,
  });

  factory Statistics.of(
    List<ActiveChallenge> all, {
    required DateTime today,
    required StatsPeriod period,
  }) {
    final t = dayOf(today);
    final from = switch (period) {
      StatsPeriod.month => DateTime.utc(t.year, t.month),
      StatsPeriod.year => DateTime.utc(t.year),
    };

    // Zähler im Zeitraum
    var daysDone = 0, done = 0, due = 0;
    final weekdayDone = List.filled(7, 0), weekdayDue = List.filled(7, 0);
    final minutes = <MinutesStat>[];
    for (final c in all) {
      for (final ci in c.checkIns) {
        if (ci.status == CheckInStatus.done && _inRange(ci.day, from, t)) {
          daysDone++;
        }
      }
      switch (c.kind) {
        case OneTimeKind():
          break;
        case WeeklyGoalKind(target: final target, unit: final unit):
          // Wochen, deren Ende (Sonntag bzw. heute) im Zeitraum liegt.
          var sum = 0;
          for (var w = weekStartOf(dayOf(c.startedOn));
              !w.isAfter(weekStartOf(t));
              w = w.add(const Duration(days: 7))) {
            final end = w.add(const Duration(days: 6));
            final weekEnd = end.isBefore(t) ? end : t;
            if (!_inRange(weekEnd, from, t) || _endedBefore(c, w)) continue;
            final value = c.weekValue(w);
            due += target;
            done += value > target ? target : value;
            if (unit == WeeklyUnit.minutes) {
              sum += _minutesBetween(c, _max(w, from), weekEnd);
            }
          }
          if (unit == WeeklyUnit.minutes && sum > 0) {
            minutes.add(MinutesStat(challenge: c, minutes: sum));
          }
        case DailyKind():
        case JournalKind():
          for (var d = _max(dayOf(c.startedOn), from);
              !d.isAfter(t);
              d = d.add(const Duration(days: 1))) {
            if (!_isDue(c, d, t)) continue;
            due++;
            weekdayDue[d.weekday - 1]++;
            if (_isDone(c, d, t)) {
              done++;
              weekdayDone[d.weekday - 1]++;
            }
          }
      }
    }

    // Heatmap und Wochen
    final thisWeek = weekStartOf(t);
    var start = thisWeek.subtract(Duration(days: 7 * (minStatsWeeks - 1)));
    for (final c in all) {
      final s = weekStartOf(dayOf(c.startedOn));
      if (s.isBefore(start)) start = s;
    }
    final earliest =
        thisWeek.subtract(Duration(days: 7 * (maxStatsWeeks - 1)));
    if (start.isBefore(earliest)) start = earliest;
    final heatmap = <double?>[];
    for (var d = start; !d.isAfter(t); d = d.add(const Duration(days: 1))) {
      var dayDue = 0, dayDone = 0;
      for (final c in all) {
        if (c.kind is OneTimeKind) continue;
        if (c.kind is WeeklyGoalKind) {
          // Wochenziele: ein Tag mit Eintrag zählt als erledigt.
          if (c.checkInOn(d)?.status == CheckInStatus.done) {
            dayDue++;
            dayDone++;
          }
          continue;
        }
        if (!_isDue(c, d, t)) continue;
        dayDue++;
        if (_isDone(c, d, t)) dayDone++;
      }
      heatmap.add(dayDue == 0 ? null : dayDone / dayDue);
    }
    final weeks = <WeekReview>[];
    for (var w = start;
        !w.isAfter(thisWeek);
        w = w.add(const Duration(days: 7))) {
      weeks.add(WeekReview.of(all, weekStart: w, today: t));
    }

    // Serien, Zähler, Listen
    var longest = 0;
    ActiveChallenge? longestChallenge;
    for (final c in all) {
      if (c.kind is OneTimeKind) continue;
      if (c.bestStreak > longest) {
        longest = c.bestStreak;
        longestChallenge = c;
      }
    }
    return Statistics._(
      from: from,
      until: t,
      daysDone: daysDone,
      done: done,
      due: due,
      longestStreak: longest,
      longestStreakChallenge: longestChallenge,
      active: all.where((c) => !c.isArchived).length,
      completed:
          all.where((c) => c.status == ChallengeStatus.completed).length,
      heatmapStart: start,
      heatmap: heatmap,
      weeks: weeks,
      weekdays: [
        for (var i = 0; i < 7; i++)
          weekdayDue[i] == 0 ? null : weekdayDone[i] / weekdayDue[i],
      ],
      minutesByChallenge: minutes,
      perChallenge: [
        for (final c in all)
          if (!c.isArchived && !c.isUpcoming(t))
            ChallengeStat(
              challenge: c,
              currentStreak: c.currentStreak(t),
              rate: c.successRate(t),
              progress: c.progress(t),
            ),
      ],
      badges: [
        for (final c in all)
          for (final m in milestones.badges(c))
            BadgeStat(challenge: c, milestone: m),
      ],
    );
  }

  /// Erster Tag des Zeitraums (UTC-Mitternacht) und heute.
  final DateTime from;
  final DateTime until;

  /// Erledigte Tage aller Arten im Zeitraum.
  final int daysDone;

  /// Erledigt und fällig im Zeitraum (siehe Klassenkommentar).
  final int done;
  final int due;
  double? get rate => due == 0 ? null : done / due;

  /// Beste Serie über alle Challenges, auch im Archiv.
  final int longestStreak;
  final ActiveChallenge? longestStreakChallenge;

  /// Laufende bzw. geschaffte Challenges.
  final int active;
  final int completed;

  /// Montag der ersten Heatmap-Woche.
  final DateTime heatmapStart;

  /// Ein Eintrag je Tag von [heatmapStart] bis heute: null = nichts fällig,
  /// sonst Anteil erledigt 0..1.
  final List<double?> heatmap;

  /// Dieselben Kalenderwochen als Rückblicke, älteste zuerst.
  final List<WeekReview> weeks;

  /// Quote je Wochentag (Index 0 = Montag) im Zeitraum; null ohne Fälliges.
  final List<double?> weekdays;

  /// Wochentag (1 = Mo … 7 = So) mit der höchsten bzw. niedrigsten Quote.
  int? get bestWeekday => _extremeWeekday(best: true);
  int? get worstWeekday => _extremeWeekday(best: false);

  int? _extremeWeekday({required bool best}) {
    int? result;
    double? value;
    for (var i = 0; i < 7; i++) {
      final v = weekdays[i];
      if (v == null) continue;
      if (value == null || (best ? v > value : v < value)) {
        value = v;
        result = i + 1;
      }
    }
    return result;
  }

  /// Minuten je Wochenziel-Challenge (in Minuten) im Zeitraum.
  final List<MinutesStat> minutesByChallenge;
  int get totalMinutes =>
      minutesByChallenge.fold(0, (sum, m) => sum + m.minutes);

  /// Laufende Challenges mit Serie, Quote und Fortschritt.
  final List<ChallengeStat> perChallenge;

  /// Alle Abzeichen mit ihrer Challenge.
  final List<BadgeStat> badges;

  static bool _inRange(DateTime day, DateTime from, DateTime until) =>
      !day.isBefore(from) && !day.isAfter(until);

  static DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  /// Challenge war an [day] schon beendet (Archiv).
  static bool _endedBefore(ActiveChallenge c, DateTime day) {
    final f = c.finishedOn;
    return f != null && dayOf(f).isBefore(day);
  }

  /// Fällig: ab Start, nicht pausiert, nicht nach dem Ende; heute nur mit
  /// Eintrag.
  static bool _isDue(ActiveChallenge c, DateTime d, DateTime today) {
    if (d.isBefore(dayOf(c.startedOn)) || d.isAfter(today)) return false;
    if (c.isPaused(d) || _endedBefore(c, d)) return false;
    if (d == today && c.checkInOn(d) == null) return false;
    return true;
  }

  static bool _isDone(ActiveChallenge c, DateTime d, DateTime today) =>
      c.statusOn(d, today: today) == DayStatus.done;

  static int _minutesBetween(
      ActiveChallenge c, DateTime from, DateTime until) {
    var sum = 0;
    for (final ci in c.checkIns) {
      if (ci.status == CheckInStatus.done && _inRange(ci.day, from, until)) {
        sum += ci.minutes ?? 0;
      }
    }
    return sum;
  }
}
