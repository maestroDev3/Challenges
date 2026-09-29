import 'active_challenge.dart';
import 'challenge.dart';
import 'challenge_repository.dart';

const actionDone = 'done';
const actionMissed = 'missed';

/// Plant und storniert Erinnerungen (Plattform-Implementierung in lib/data).
abstract interface class ReminderScheduler {
  Future<void> schedule(ActiveChallenge challenge);
  Future<void> cancel(ActiveChallenge challenge);
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

/// Wann und wie oft erinnert wird.
sealed class ReminderPlan {
  const ReminderPlan();
}

class NoReminder extends ReminderPlan {
  const NoReminder();
}

/// Einmaliger Termin (einmalige Challenge oder flexibles Wochenziel, das
/// nach jedem Abhaken neu geplant wird).
class OnceReminder extends ReminderPlan {
  const OnceReminder(this.at);
  final DateTime at;
}

/// Täglich ab [first] zur selben Uhrzeit.
class DailyReminder extends ReminderPlan {
  const DailyReminder(this.first);
  final DateTime first;
}

/// Wöchentlich an geplanten Tagen: je Wochentag der erste Termin.
class WeekdayReminders extends ReminderPlan {
  const WeekdayReminders(this.firsts);
  final Map<int, DateTime> firsts;
}

DateTime _at(DateTime d, ReminderTime t) =>
    DateTime(d.year, d.month, d.day, t.hour, t.minute);

ReminderPlan reminderPlan(ActiveChallenge c, DateTime now) {
  if (c.isArchived || c.isCompleted) return const NoReminder();
  final time = c.reminder;
  switch (c.kind) {
    case OneTimeKind():
      final at = firstReminder(c, now);
      return at == null ? const NoReminder() : OnceReminder(at);
    case WeeklyGoalKind(weekdays: final days) when days.isNotEmpty:
      final firsts = <int, DateTime>{};
      for (final wd in days) {
        var d = nextReminder(now, time);
        while (d.weekday != wd) {
          d = _at(d.add(const Duration(days: 1)), time);
        }
        for (var i = 0; i < 60 && c.isPaused(d); i++) {
          d = _at(d.add(const Duration(days: 7)), time);
        }
        firsts[wd] = d;
      }
      return WeekdayReminders(firsts);
    case WeeklyGoalKind(target: final target):
      var d = nextReminder(now, time);
      for (var i = 0; i < 400; i++) {
        if (!c.isPaused(d) && c.weekValue(d) < target) return OnceReminder(d);
        d = _at(d.add(const Duration(days: 1)), time);
      }
      return const NoReminder();
    default:
      final first = firstReminder(c, now);
      return first == null ? const NoReminder() : DailyReminder(first);
  }
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
    if (reminderPlan(c, now) is NoReminder) {
      await scheduler.cancel(c);
    } else {
      await scheduler.schedule(c);
    }
  }
}
