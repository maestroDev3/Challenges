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

  @override
  Future<void> cancel(ActiveChallenge challenge) async {
    scheduled.remove(challenge.id);
    cancelled.add(challenge.id);
  }
}
