import 'package:challenges/data/local_challenge_repository.dart';
import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge_repository.dart';
import 'package:challenges/domain/reminders.dart';
import 'package:challenges/domain/store_codec.dart';
import 'package:challenges/domain/widget_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mittwoch, 30. September 2026, 20 Uhr.
final now = DateTime(2026, 9, 30, 20);
final today = dayOf(now);
DateTime inDays(int n) => today.add(Duration(days: n));

ActiveChallenge planned(String templateId, {int inDaysFromNow = 3}) =>
    ActiveChallenge(
      id: templateId,
      template: templateById(templateId)!,
      startedOn: inDays(inDaysFromNow),
      reminder: const ReminderTime(7, 0),
    );

void main() {
  group('geplante Challenge', () {
    test('vor dem Start: geplant, keine Streak, kein Fortschritt', () {
      final c = planned('wake-5am');
      expect(c.isUpcoming(now), isTrue);
      expect(c.daysUntilStart(now), 3);
      expect(c.currentStreak(now), 0);
      expect(c.progress(now) ?? 0, 0);
    });

    test('am Starttag automatisch aktiv', () {
      final c = planned('wake-5am');
      final startDay = DateTime(2026, 10, 3, 6);
      expect(c.isUpcoming(startDay), isFalse);
      expect(c.daysUntilStart(startDay), 0);
    });

    test('startNow setzt den Start auf heute', () {
      final c = planned('wake-5am').startNow(now);
      expect(c.startedOn, today);
      expect(c.isUpcoming(now), isFalse);
    });

    test('withStart verschiebt den Start innerhalb von 90 Tagen', () {
      final c = planned('wake-5am');
      expect(c.withStart(inDays(10), today: now).startedOn, inDays(10));
      expect(() => c.withStart(inDays(91), today: now), throwsArgumentError);
      expect(() => c.withStart(inDays(-1), today: now), throwsArgumentError);
    });

    test('Check-in vor dem Start wird abgewiesen', () {
      expect(() => planned('wake-5am').checkIn(now, CheckInStatus.done),
          throwsStateError);
    });
  });

  group('Erinnerungen und Widget', () {
    test('erste Erinnerung am Starttag zur gewählten Uhrzeit, keine davor', () {
      final times = upcomingReminders(planned('wake-5am'), now);
      expect(times.first, DateTime(2026, 10, 3, 7));
    });

    test('auch firstReminder beginnt am Starttag', () {
      expect(firstReminder(planned('cold-shower'), now),
          DateTime(2026, 10, 3, 7));
    });

    test('geplante Challenges fehlen im Widget', () {
      final running = ActiveChallenge(
        id: 'r',
        template: templateById('cold-shower')!,
        startedOn: today,
        reminder: const ReminderTime(7, 0),
      );
      final entries = widgetEntries([running, planned('wake-5am')], now);
      expect(entries.map((e) => e.id), ['r']);
    });
  });

  group('Speicher', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<LocalChallengeRepository> repo() async => LocalChallengeRepository(
        await SharedPreferences.getInstance(),
        clock: () => now);

    test('start mit Starttag in der Zukunft', () async {
      final r = await repo();
      final c = await r.start(templateById('wake-5am')!, const ReminderTime(5, 0),
          startOn: inDays(3));
      expect(c.startedOn, inDays(3));
      expect(c.isUpcoming(now), isTrue);
    });

    test('Starttag mehr als 90 Tage voraus oder in der Vergangenheit: Fehler',
        () async {
      final r = await repo();
      expect(
          () => r.start(templateById('wake-5am')!, const ReminderTime(5, 0),
              startOn: inDays(91)),
          throwsArgumentError);
      expect(
          () => r.start(templateById('wake-5am')!, const ReminderTime(5, 0),
              startOn: inDays(-1)),
          throwsArgumentError);
    });

    test('geplante Challenge blockiert ihre Vorlage', () async {
      final r = await repo();
      final first = await r.start(
          templateById('wake-5am')!, const ReminderTime(5, 0),
          startOn: inDays(3));
      final second =
          await r.start(templateById('wake-5am')!, const ReminderTime(6, 0));
      expect(second.id, first.id);
      expect((await r.active()), hasLength(1));
    });

    test('Start in der Zukunft übersteht Speichern und Laden', () {
      final store = ChallengeStore(active: [planned('wake-5am')]);
      final loaded = decodeStore(encodeStore(store));
      expect(loaded.active.single.startedOn, inDays(3));
      expect(loaded.active.single.isUpcoming(now), isTrue);
    });
  });
}
