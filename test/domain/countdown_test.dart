import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

final startAt = DateTime(2026, 10, 10, 8, 0);

ActiveChallenge fasting() => ActiveChallenge(
      id: 'f',
      template: templateById('fasting-24h')!,
      startedOn: dayOf(startAt),
      reminder: const ReminderTime(9, 0),
    );

void main() {
  test('noch nicht gestartet', () {
    final c = fasting();
    expect(c.windowStartedAt, isNull);
    expect(c.remaining(startAt), isNull);
    expect(c.windowEnded(startAt), isFalse);
  });

  test('Restzeit und Fortschritt aus Startzeit, Fenster und Uhr', () {
    final c = fasting().startWindow(startAt);
    final now = DateTime(2026, 10, 10, 18, 38);
    expect(c.remaining(now), const Duration(hours: 13, minutes: 22));
    expect(c.windowProgress(now), closeTo(638 / 1440, 1e-9));
    expect(c.windowEnd, DateTime(2026, 10, 11, 8, 0));
    expect(c.windowEnded(now), isFalse);
  });

  test('nach Ablauf: beendet, Restzeit 0', () {
    final c = fasting().startWindow(startAt);
    final later = DateTime(2026, 10, 11, 8, 5);
    expect(c.windowEnded(later), isTrue);
    expect(c.remaining(later), Duration.zero);
    expect(c.windowProgress(later), 1.0);
  });

  test('Abbrechen setzt auf „nicht gestartet“ zurück', () {
    final c = fasting().startWindow(startAt).cancelWindow();
    expect(c.windowStartedAt, isNull);
  });

  test('Erinnerung genau zum Ende, danach keine', () {
    final c = fasting().startWindow(startAt);
    expect(firstReminder(c, DateTime(2026, 10, 10, 12)),
        DateTime(2026, 10, 11, 8, 0));
    expect(reminderRepeats(c), isFalse);
    expect(firstReminder(c, DateTime(2026, 10, 11, 9)), isNull);
  });
}
