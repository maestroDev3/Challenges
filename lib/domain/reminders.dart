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
  if (challenge == null) return false;

  switch (challenge.kind) {
    case WeeklyGoalKind():
      return false;
    case JournalKind() when status == CheckInStatus.done:
      final note = input?.trim() ?? '';
      if (note.isEmpty) return false;
      await repository.save(challenge.checkIn(now, status, note: note));
      return true;
    default:
      await repository.save(challenge.checkIn(now, status));
      return true;
  }
}

/// Plant Erinnerungen für alle laufenden Challenges neu und storniert
/// die von abgeschlossenen.
Future<void> syncReminders(
    ChallengeRepository repository, ReminderScheduler scheduler) async {
  for (final c in await repository.active()) {
    if (c.isCompleted) {
      await scheduler.cancel(c);
    } else {
      await scheduler.schedule(c);
    }
  }
}
