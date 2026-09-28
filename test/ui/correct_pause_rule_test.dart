import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/catalog_screen.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/pump_app.dart';

// Sonntag, 25. Oktober 2026
final today = DateTime(2026, 10, 25, 9);
DateTime daysAgo(int n) => today.subtract(Duration(days: n));

ActiveChallenge running(
  String id, {
  int startedDaysAgo = 5,
  Iterable<int> doneDaysAgo = const [],
  Iterable<int> missedDaysAgo = const [],
  StreakRule rule = StreakRule.relaxed,
}) {
  var c = ActiveChallenge(
    id: id,
    template: templateById(id)!,
    startedOn: dayOf(daysAgo(startedDaysAgo)),
    reminder: const ReminderTime(7, 0),
    rule: rule,
  );
  for (final n in doneDaysAgo) {
    c = c.checkIn(daysAgo(n), CheckInStatus.done);
  }
  for (final n in missedDaysAgo) {
    c = c.checkIn(daysAgo(n), CheckInStatus.missed);
  }
  return c;
}

Future<void> pumpToday(WidgetTester tester, FakeChallengeRepository repo,
        {FakeReminderScheduler? scheduler}) =>
    tester.pumpApp(TodayScreen(
      repository: repo,
      clock: () => today,
      onDiscover: () {},
      scheduler: scheduler,
    ));

void main() {
  group('Nachtragen', () {
    testWidgets('gestern auf „Erledigt“ setzen aktualisiert die Streak',
        (tester) async {
      final repo = FakeChallengeRepository(
          initial: [running('wake-5am', doneDaysAgo: [2, 3])]);
      await pumpToday(tester, repo);
      expect(find.text('🔥 0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('day-5'))); // gestern
      await tester.pumpAndSettle();
      expect(find.text('Sa, 24.10.'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Erledigt'));
      await tester.pumpAndSettle();

      expect(repo.items.single.checkInOn(daysAgo(1))!.status,
          CheckInStatus.done);
      expect(find.text('🔥 3'), findsOneWidget);
    });

    testWidgets('„Leer“ entfernt den Eintrag', (tester) async {
      final repo = FakeChallengeRepository(
          initial: [running('wake-5am', doneDaysAgo: [1])]);
      await pumpToday(tester, repo);
      await tester.tap(find.byKey(const Key('day-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Leer'));
      await tester.pumpAndSettle();
      expect(repo.items.single.checkInOn(daysAgo(1)), isNull);
    });

    testWidgets('Tage vor dem Start sind nicht antippbar', (tester) async {
      final repo = FakeChallengeRepository(
          initial: [running('wake-5am', startedDaysAgo: 0)]);
      await pumpToday(tester, repo);
      await tester.tap(find.byKey(const Key('day-5')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Leer'), findsNothing);
    });
  });

  group('Pausieren', () {
    testWidgets('pausieren zeigt „Pausiert bis …“ und plant nach der Pause',
        (tester) async {
      final repo = FakeChallengeRepository(
          initial: [running('wake-5am', doneDaysAgo: [1, 2])]);
      final scheduler = FakeReminderScheduler();
      await pumpToday(tester, repo, scheduler: scheduler);

      await tester.tap(find.byTooltip('Mehr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pausieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 Tage'));
      await tester.pumpAndSettle();

      final c = repo.items.single;
      expect(c.isPaused(today), isTrue);
      expect(c.pausedUntil(today), dayOf(daysAgo(-2)));
      expect(find.text('Pausiert bis 27.10.'), findsOneWidget);
      expect(find.text('Erledigt'), findsNothing);
      expect(find.text('🔥 2'), findsOneWidget);
      expect(scheduler.scheduleCalls, 1);

      await tester.tap(find.text('Fortsetzen'));
      await tester.pumpAndSettle();
      expect(repo.items.single.isPaused(today), isFalse);
      expect(find.text('Erledigt'), findsOneWidget);
      expect(scheduler.scheduleCalls, 2);
    });
  });

  group('Regel', () {
    testWidgets('Regel wird beim Starten gewählt und gespeichert',
        (tester) async {
      final repo = FakeChallengeRepository();
      await tester.pumpApp(CatalogScreen(repository: repo));
      await tester.tap(find.text('Um 5 Uhr aufstehen'));
      await tester.pumpAndSettle();
      expect(find.text('Locker'), findsOneWidget);
      await tester.tap(find.text('Hart'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Neustart bei Tag 1'), findsOneWidget);
      await tester.tap(find.text('Challenge starten'));
      await tester.pumpAndSettle();
      expect(repo.items.single.rule, StreakRule.strict);
    });

    testWidgets('Karte zeigt Joker und Versuch', (tester) async {
      final repo = FakeChallengeRepository(initial: [
        running('wake-5am',
            startedDaysAgo: 8,
            doneDaysAgo: [1, 2, 3, 4, 5, 6, 7],
            rule: StreakRule.joker),
        running('no-sugar',
            startedDaysAgo: 3,
            doneDaysAgo: [2, 3],
            missedDaysAgo: [1],
            rule: StreakRule.strict),
      ]);
      await pumpToday(tester, repo);
      expect(find.text('🛡️ 1'), findsOneWidget);
      expect(find.text('Versuch 2'), findsOneWidget);
    });
  });
}
