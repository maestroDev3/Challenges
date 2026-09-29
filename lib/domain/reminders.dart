import 'active_challenge.dart';
import 'challenge.dart';
import 'challenge_repository.dart';

const actionDone = 'done';
const actionMissed = 'missed';
const actionStop = 'stop';

/// Plant und storniert Erinnerungen (Plattform-Implementierung in lib/data).
abstract interface class ReminderScheduler {
  Future<void> schedule(ActiveChallenge challenge);
  Future<void> cancel(ActiveChallenge challenge);

  /// Laufende Benachrichtigung mit Stoppuhr und „Stopp“ (und Signal bei
  /// erreichter Zieldauer).
  Future<void> showSession(ActiveChallenge challenge);

  Future<void> clearSession(ActiveChallenge challenge);
}

/// Stabile, positive 31-Bit-Id pro Challenge (FNV-1a), unabhängig vom
/// Dart-`hashCode`, damit sie über App-Starts gleich bleibt.
int notificationIdFor(String challengeId) {
  var hash = 0x811c9dc5;
  for (final unit in challengeId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Nächster Zeitpunkt der Erinnerung: heute, falls noch nicht vorbei, sonst morgen.
DateTime nextReminder(DateTime now, ReminderTime time) {
  final today = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
}

/// Welche Aktionen die Benachrichtigung anbietet.
enum ReminderActions { doneMissed, journalInput, none }

ReminderActions reminderActionsFor(ChallengeKind kind) => switch (kind) {
      JournalKind() => ReminderActions.journalInput,
      WeeklyGoalKind(unit: WeeklyUnit.minutes) => ReminderActions.none,
      _ => ReminderActions.doneMissed,
    };

/// Täglich wiederholen (alles außer einmaligen Challenges).
bool reminderRepeats(ActiveChallenge c) => c.kind is! OneTimeKind;

/// Erster Erinnerungstermin ab [now] oder null, wenn keine Erinnerung nötig
/// ist. Pausierte Tage werden übersprungen; einmalige Challenges mit Datum
/// erinnern genau an diesem Tag.
DateTime? firstReminder(ActiveChallenge c, DateTime now) {
  if (c.isArchived || c.isCompleted) return null;
  final time = c.reminder;
  if (c.windowEnd case final end?) {
    return end.isAfter(now) ? end : null;
  }
  if (c.kind case OneTimeKind(date: final date?)) {
    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    return at.isAfter(now) ? at : null;
  }
  var at = nextReminder(now, time);
  for (var i = 0; i < 400 && c.isPaused(at); i++) {
    at = DateTime(at.year, at.month, at.day + 1, time.hour, time.minute);
  }
  return at;
}

/// So viele Termine werden je Challenge im Voraus geplant.
const maxUpcomingReminders = 14;

DateTime _at(DateTime d, ReminderTime t) =>
    DateTime(d.year, d.month, d.day, t.hour, t.minute);

/// Die nächsten konkreten Erinnerungstermine ab [now].
///
/// Bewusst keine wiederholenden Benachrichtigungen: Android berechnet deren
/// nächsten Termin selbst und würde Pausen ignorieren (#72). Ausgelassen
/// werden pausierte Tage, nicht geplante Wochentage und – beim flexiblen
/// Wochenziel – Tage, an denen das Ziel der Woche schon erreicht ist.
/// Die Liste wird nach jeder Änderung neu berechnet.
List<DateTime> upcomingReminders(ActiveChallenge c, DateTime now,
    {int max = maxUpcomingReminders}) {
  if (c.isArchived || c.isCompleted) return const [];
  final kind = c.kind;
  if (kind is OneTimeKind) {
    final at = firstReminder(c, now);
    return at == null ? const [] : [at];
  }
  final result = <DateTime>[];
  var d = nextReminder(now, c.reminder);
  for (var i = 0; i < 120 && result.length < max; i++) {
    final due = switch (kind) {
      WeeklyGoalKind(weekdays: final days) when days.isNotEmpty =>
        days.contains(d.weekday),
      WeeklyGoalKind(target: final target) => c.weekValue(d) < target,
      _ => true,
    };
    if (due && !c.isPaused(d)) result.add(d);
    d = _at(d.add(const Duration(days: 1)), c.reminder);
  }
  return result;
}

/// Verarbeitet einen Tipp auf „Erledigt“ / „Nicht erledigt“ in der
/// Benachrichtigung. Gibt true zurück, wenn ein Check-in gespeichert wurde.
Future<bool> handleNotificationAction(
  ChallengeRepository repository, {
  required String? actionId,
  required String? payload,
  required DateTime now,
  String? input,
}) async {
  if (actionId == actionStop && payload != null) {
    final c = await repository.byId(payload);
    if (c == null || c.sessionStartedAt == null) return false;
    final stopped = c.stopSession(now);
    await repository.save(stopped);
    if (stopped.shouldAutoFinish(now)) await repository.finish(stopped.id);
    return true;
  }
  final status = switch (actionId) {
    actionDone => CheckInStatus.done,
    actionMissed => CheckInStatus.missed,
    _ => null,
  };
  if (status == null || payload == null) return false;
  final challenge = await repository.byId(payload);
  if (challenge == null || challenge.isArchived) return false;

  final ActiveChallenge updated;
  switch (challenge.kind) {
    case WeeklyGoalKind(unit: WeeklyUnit.minutes):
      return false;
    case JournalKind() when status == CheckInStatus.done:
      final note = input?.trim() ?? '';
      if (note.isEmpty) return false;
      updated = challenge.checkIn(now, status, note: note);
    default:
      updated = challenge.checkIn(now, status);
  }
  await repository.save(updated);
  if (updated.shouldAutoFinish(now)) await repository.finish(updated.id);
  return true;
}

/// Plant Erinnerungen für alle aktiven Challenges neu (pausierte ab dem
/// ersten Tag nach der Pause) und storniert die, die keine mehr brauchen.
Future<void> syncReminders(
  ChallengeRepository repository,
  ReminderScheduler scheduler, {
  required DateTime now,
}) async {
  for (final c in await repository.active()) {
    if (upcomingReminders(c, now).isEmpty) {
      await scheduler.cancel(c);
    } else {
      await scheduler.schedule(c);
    }
  }
}
