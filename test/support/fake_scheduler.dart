import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/reminders.dart';

class FakeReminderScheduler implements ReminderScheduler {
  final scheduled = <String>{};
  final cancelled = <String>[];
  var scheduleCalls = 0;

  @override
  Future<void> schedule(ActiveChallenge challenge) async {
    scheduleCalls++;
    scheduled.add(challenge.id);
  }

  final sessionsShown = <String>[];
  final sessionsCleared = <String>[];

  @override
  Future<void> showSession(ActiveChallenge challenge) async =>
      sessionsShown.add(challenge.id);

  @override
  Future<void> clearSession(ActiveChallenge challenge) async =>
      sessionsCleared.add(challenge.id);

  @override
  Future<void> cancel(ActiveChallenge challenge) async {
    scheduled.remove(challenge.id);
    cancelled.add(challenge.id);
  }
}
