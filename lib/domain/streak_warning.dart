import 'active_challenge.dart';
import 'challenge.dart';
import 'challenge_repository.dart';
import 'reminders.dart';
import 'settings.dart';

/// Ab dieser Serie warnt die App abends (Verlustaversion greift erst, wenn
/// es etwas zu verlieren gibt).
const minStreakForWarning = 3;

/// Eine Serie, die heute noch offen ist. Bei Wochenzielen (nur sonntags)
/// stehen [weeklyDone]/[weeklyTarget], sonst [streak].
class StreakWarning {
  const StreakWarning({
    required this.challenge,
    required this.streak,
    required this.jokerAvailable,
    this.weeklyDone,
    this.weeklyTarget,
  });

  final ActiveChallenge challenge;
  final int streak;
  final bool jokerAvailable;
  final int? weeklyDone;
  final int? weeklyTarget;

  bool get isWeekly => weeklyTarget != null;
}

/// Warnung für [c] an [today] – oder null, wenn nichts zu retten ist:
/// tägliche und Journal-Challenges ab Serie [minStreakForWarning], heute
/// fällig und ohne Eintrag; Wochenziele nur sonntags bei offenem Ziel.
StreakWarning? streakWarningFor(ActiveChallenge c, DateTime today) {
  final t = dayOf(today);
  if (c.isArchived || c.isUpcoming(t) || c.isPaused(t)) return null;
  switch (c.kind) {
    case OneTimeKind():
      return null;
    case WeeklyGoalKind(target: final target):
      if (t.weekday != DateTime.sunday) return null;
      final value = c.weekValue(t);
      if (value >= target) return null;
      return StreakWarning(
        challenge: c,
        streak: c.currentStreak(t),
        jokerAvailable: false,
        weeklyDone: value,
        weeklyTarget: target,
      );
    case DailyKind():
    case JournalKind():
      if (c.checkInOn(t) != null) return null;
      final streak = c.currentStreak(t);
      if (streak < minStreakForWarning) return null;
      return StreakWarning(
        challenge: c,
        streak: streak,
        jokerAvailable: c.rule == StreakRule.joker && c.jokers(t) > 0,
      );
  }
}

/// Alle offenen Serien für die Zeile im Tab „Statistik“.
List<StreakWarning> openStreaks(List<ActiveChallenge> all, DateTime today) =>
    [
      for (final c in all)
        if (streakWarningFor(c, today) case final w?) w,
    ];

/// Zeitpunkte der Warn-Benachrichtigung: heute zur eingestellten Zeit, falls
/// die Warnung gilt und die Zeit noch nicht vorbei ist; ist heute schon
/// erledigt und die Serie lang genug, morgen. Danach plant jeder Sync neu.
List<DateTime> upcomingStreakWarnings(
  ActiveChallenge c,
  DateTime now,
  AppSettings settings,
) {
  if (!settings.streakWarningEnabled) return const [];
  final time = settings.streakWarningTime;
  DateTime at(DateTime d) =>
      DateTime(d.year, d.month, d.day, time.hour, time.minute);
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (streakWarningFor(c, today) != null) {
    final t = at(today);
    return t.isAfter(now) ? [t] : const [];
  }
  if (c.kind is WeeklyGoalKind || c.isArchived) return const [];
  final doneToday = c.checkInOn(today)?.status == CheckInStatus.done;
  if (doneToday &&
      c.currentStreak(today) >= minStreakForWarning &&
      !c.isPaused(tomorrow)) {
    return [at(tomorrow)];
  }
  return const [];
}

/// Plant die Warnungen aller aktiven Challenges neu bzw. löscht sie.
Future<void> syncStreakWarnings(
  ChallengeRepository repository,
  ReminderScheduler scheduler, {
  required DateTime now,
  required AppSettings settings,
}) async {
  for (final c in await repository.active()) {
    final times = upcomingStreakWarnings(c, now, settings);
    if (times.isEmpty) {
      await scheduler.cancelStreakWarning(c);
    } else {
      await scheduler.scheduleStreakWarning(c, times);
    }
  }
}
