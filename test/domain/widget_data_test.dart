import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/widget_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';

final today = DateTime(2026, 10, 7, 12);
DateTime ago(int n) => today.subtract(Duration(days: n));

ActiveChallenge running(String id, {Iterable<int> doneAgo = const []}) {
  var c = ActiveChallenge(
    id: id,
    template: templateById(id)!,
    startedOn: dayOf(ago(10)),
    reminder: const ReminderTime(7, 0),
  );
  for (final n in doneAgo) {
    c = c.checkIn(ago(n), CheckInStatus.done);
  }
  return c;
}

void main() {
  group('widgetEntries', () {
    test('Titel, Streak und Status heute; offene zuerst', () {
      final entries = widgetEntries([
        running('wake-5am', doneAgo: [0, 1, 2]),
        running('cold-shower', doneAgo: [1]),
      ], today);
      expect(entries.map((e) => e.id), ['cold-shower', 'wake-5am']);
      expect(entries.first.title, '🧊 Kalt duschen');
      expect(entries.first.streak, '🔥 1');
      expect(entries.first.doneToday, isFalse);
      expect(entries.last.doneToday, isTrue);
      expect(entries.last.streak, '🔥 3');
    });

    test('höchstens vier, pausierte fehlen', () {
      final entries = widgetEntries([
        for (final id in ['wake-5am', 'cold-shower', 'no-sugar', 'meditate-sleep', 'eye-gaze'])
          running(id),
        running('morning-routine').pause(from: ago(0), until: ago(-3)),
      ], today);
      expect(entries, hasLength(maxWidgetEntries));
      expect(entries.map((e) => e.id), isNot(contains('morning-routine')));
    });
  });

  group('handleWidgetTap', () {
    test('Haken speichert „erledigt“ für heute', () async {
      final repo = FakeChallengeRepository(initial: [running('wake-5am')]);
      final ok = await handleWidgetTap(repo,
          Uri.parse('ritual://check?id=wake-5am'), now: today);
      expect(ok, isTrue);
      expect(repo.items.single.checkInOn(today)!.status, CheckInStatus.done);
    });

    test('bereits erledigt oder unbekannt ändert nichts', () async {
      final repo = FakeChallengeRepository(
          initial: [running('wake-5am', doneAgo: [0])]);
      expect(
          await handleWidgetTap(repo, Uri.parse('ritual://check?id=wake-5am'),
              now: today),
          isFalse);
      expect(
          await handleWidgetTap(repo, Uri.parse('ritual://check?id=gibts-nicht'),
              now: today),
          isFalse);
      expect(await handleWidgetTap(repo, null, now: today), isFalse);
    });
  });
}
