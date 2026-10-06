import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/reminders.dart';
import 'package:challenges/domain/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';

/// Mittwoch, 30.09.2026, 10:00
final wednesday = DateTime(2026, 9, 30, 10, 0);
final sunday1800 = DateTime(2026, 10, 4, 18, 0);
final sunday2000 = DateTime(2026, 10, 4, 20, 0);

ActiveChallenge running() => ActiveChallenge(
      id: 'a',
      template: templateById('meditate-sleep')!,
      startedOn: DateTime(2026, 9, 28),
      reminder: const ReminderTime(7, 0),
    );

void main() {
  group('AppSettings Wochenrückblick', () {
    test('Standard: eingeschaltet, 19:00', () {
      const s = AppSettings();
      expect(s.weekReviewEnabled, isTrue);
      expect(s.weekReviewTime, const ReminderTime(19, 0));
    });

    test('copyWith ändert Schalter und Uhrzeit', () {
      final s = const AppSettings().copyWith(
        weekReviewEnabled: false,
        weekReviewTime: const ReminderTime(20, 30),
      );
      expect(s.weekReviewEnabled, isFalse);
      expect(s.weekReviewTime, const ReminderTime(20, 30));
      expect(s.copyWith(name: 'Mia').weekReviewTime,
          const ReminderTime(20, 30));
    });

    test('Speichern und Lesen ergibt dieselben Werte', () {
      final s = const AppSettings().copyWith(
        weekReviewEnabled: false,
        weekReviewTime: const ReminderTime(21, 15),
      );
      expect(decodeSettings(encodeSettings(s)), s);
    });

    test('Einstellungen ohne die neuen Schlüssel laden mit Standardwerten',
        () {
      final s = decodeSettings('{"name":"Mia","showIntro":false}');
      expect(s.name, 'Mia');
      expect(s.weekReviewEnabled, isTrue);
      expect(s.weekReviewTime, const ReminderTime(19, 0));
    });
  });

  group('nextWeekReview', () {
    test('an einem Mittwoch: der kommende Sonntag 19:00', () {
      expect(
        nextWeekReview(wednesday, const AppSettings(), hasActive: true),
        DateTime(2026, 10, 4, 19, 0),
      );
    });

    test('am Sonntag um 18:00: heute 19:00; um 20:00: der Sonntag darauf',
        () {
      expect(
        nextWeekReview(sunday1800, const AppSettings(), hasActive: true),
        DateTime(2026, 10, 4, 19, 0),
      );
      expect(
        nextWeekReview(sunday2000, const AppSettings(), hasActive: true),
        DateTime(2026, 10, 11, 19, 0),
      );
    });

    test('nutzt die eingestellte Uhrzeit', () {
      final s = const AppSettings()
          .copyWith(weekReviewTime: const ReminderTime(20, 30));
      expect(
        nextWeekReview(wednesday, s, hasActive: true),
        DateTime(2026, 10, 4, 20, 30),
      );
    });

    test('ausgeschaltet: null', () {
      final s = const AppSettings().copyWith(weekReviewEnabled: false);
      expect(nextWeekReview(wednesday, s, hasActive: true), isNull);
    });

    test('ohne aktive Challenge: null', () {
      expect(
        nextWeekReview(wednesday, const AppSettings(), hasActive: false),
        isNull,
      );
    });
  });

  group('syncReminders mit Einstellungen', () {
    test('plant die Wochen-Benachrichtigung bei aktiver Challenge', () async {
      final repo = FakeChallengeRepository(initial: [running()]);
      final scheduler = FakeReminderScheduler();
      await syncReminders(repo, scheduler,
          now: wednesday, settings: const AppSettings());
      expect(scheduler.weekReviewAt, DateTime(2026, 10, 4, 19, 0));
    });

    test('ausgeschaltet: plant keine und löscht eine bestehende', () async {
      final repo = FakeChallengeRepository(initial: [running()]);
      final scheduler = FakeReminderScheduler()
        ..weekReviewAt = DateTime(2026, 10, 4, 19, 0);
      await syncReminders(repo, scheduler,
          now: wednesday,
          settings: const AppSettings().copyWith(weekReviewEnabled: false));
      expect(scheduler.weekReviewAt, isNull);
      expect(scheduler.weekReviewCancelled, 1);
    });

    test('ohne aktive Challenge wird keine Wochen-Benachrichtigung geplant',
        () async {
      final repo = FakeChallengeRepository();
      final scheduler = FakeReminderScheduler();
      await syncReminders(repo, scheduler,
          now: wednesday, settings: const AppSettings());
      expect(scheduler.weekReviewAt, isNull);
    });

    test('ohne Einstellungen bleibt alles wie bisher', () async {
      final repo = FakeChallengeRepository(initial: [running()]);
      final scheduler = FakeReminderScheduler();
      await syncReminders(repo, scheduler, now: wednesday);
      expect(scheduler.weekReviewAt, isNull);
      expect(scheduler.weekReviewCancelled, 0);
    });
  });

  test('der Payload der Wochen-Benachrichtigung ist erkennbar', () {
    expect(isWeekReviewPayload(weekReviewPayload), isTrue);
    expect(isWeekReviewPayload('meditate-sleep'), isFalse);
    expect(isWeekReviewPayload(null), isFalse);
  });
}
