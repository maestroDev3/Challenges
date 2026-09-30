import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/ui/app.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/german_device.dart';
import '../support/pump_app.dart';

final today = DateTime(2026, 10, 7, 12);
DateTime ago(int n) => today.subtract(Duration(days: n));

ActiveChallenge running(ChallengeTemplate t, {Iterable<int> doneAgo = const []}) {
  var c = ActiveChallenge(
    id: t.id,
    template: t,
    startedOn: dayOf(ago(10)),
    reminder: const ReminderTime(7, 0),
  );
  for (final n in doneAgo) {
    c = c.checkIn(ago(n), CheckInStatus.done);
  }
  return c;
}

Future<void> openAdjust(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Mehr'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Anpassen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Erinnerungszeit ändern: Verlauf bleibt, neu geplant',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [
      running(templateById('cold-shower')!, doneAgo: [1, 2, 3])
    ]);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(TodayScreen(
      repository: repo,
      clock: () => today,
      onDiscover: () {},
      scheduler: scheduler,
      pickTime: (_, _) async => const TimeOfDay(hour: 20, minute: 30),
    ));
    await openAdjust(tester);
    expect(find.text('07:00'), findsOneWidget);
    await tester.tap(find.text('Erinnerung'));
    await tester.pumpAndSettle();
    expect(find.text('20:30'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    final c = repo.items.single;
    expect(c.reminder, const ReminderTime(20, 30));
    expect(c.doneDays, 3);
    expect(c.startedOn, dayOf(ago(10)));
    expect(scheduler.scheduleCalls, 1);
  });

  testWidgets('nur passende Regeln; X Tage kann „Hart“', (tester) async {
    final repo = FakeChallengeRepository(initial: [
      running(templateById('meditate-sleep')!),
    ]);
    await tester.pumpApp(TodayScreen(
        repository: repo, clock: () => today, onDiscover: () {}));
    await openAdjust(tester);
    expect(find.text('Locker'), findsOneWidget);
    expect(find.text('Hart'), findsNothing);
  });

  testWidgets('Regel wechseln wird gespeichert', (tester) async {
    final repo = FakeChallengeRepository(initial: [
      running(templateById('no-sugar')!),
    ]);
    await tester.pumpApp(TodayScreen(
        repository: repo, clock: () => today, onDiscover: () {}));
    await openAdjust(tester);
    await tester.tap(find.text('Hart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(repo.items.single.rule, StreakRule.strict);
  });

  testWidgets('eigene Challenge: „Art und Details bearbeiten“ öffnet Editor',
      (tester) async {
    final t = ChallengeTemplate.custom(
        title: 'Laufen',
        kind: const WeeklyGoalKind(3, unit: WeeklyUnit.times));
    final repo = FakeChallengeRepository(initial: [running(t)], templates: [t]);
    await tester.pumpApp(TodayScreen(
        repository: repo, clock: () => today, onDiscover: () {}));
    await openAdjust(tester);
    await tester.tap(find.text('Art und Details bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.text('Challenge bearbeiten'), findsOneWidget);
  });

  testWidgets('App ist auf Deutsch lokalisiert', (tester) async {
    useGermanDevice(tester);
    await tester.pumpWidget(ChallengesApp(repository: FakeChallengeRepository()));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Heute').first);
    expect(Localizations.localeOf(context), const Locale('de'));
    expect(MaterialLocalizations.of(context).okButtonLabel, 'OK');
    expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Abbrechen');
  });
}
