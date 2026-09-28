import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/pump_app.dart';

final startAt = DateTime(2026, 10, 10, 8, 0);

ActiveChallenge fasting({DateTime? started}) {
  final c = ActiveChallenge(
    id: 'f',
    template: templateById('fasting-24h')!,
    startedOn: dayOf(startAt),
    reminder: const ReminderTime(9, 0),
  );
  return started == null ? c : c.startWindow(started);
}

void main() {
  testWidgets('„Jetzt starten“ setzt die Startzeit und plant das Ende',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [fasting()]);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(TodayScreen(
        repository: repo,
        clock: () => startAt,
        onDiscover: () {},
        scheduler: scheduler));
    expect(find.text('Erledigt'), findsNothing);
    await tester.tap(find.text('Jetzt starten'));
    await tester.pumpAndSettle();
    expect(repo.items.single.windowStartedAt, startAt);
    expect(scheduler.scheduleCalls, 1);
    expect(find.text('noch 24:00 h'), findsOneWidget);
  });

  testWidgets('Karte zählt live herunter', (tester) async {
    var now = DateTime(2026, 10, 10, 18, 38);
    final repo = FakeChallengeRepository(initial: [fasting(started: startAt)]);
    await tester.pumpApp(TodayScreen(
        repository: repo, clock: () => now, onDiscover: () {}));
    expect(find.text('noch 13:22 h'), findsOneWidget);
    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('noch 13:20 h'), findsOneWidget);
  });

  testWidgets('nach Ablauf fragt die Karte „Geschafft?“', (tester) async {
    final now = DateTime(2026, 10, 11, 8, 30);
    final repo = FakeChallengeRepository(
        initial: [fasting(started: startAt)], today: now);
    await tester.pumpApp(TodayScreen(
        repository: repo, clock: () => now, onDiscover: () {}));
    expect(find.text('Geschafft?'), findsOneWidget);
    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();
    expect(find.text('Geschafft! 🏆'), findsOneWidget);
    expect(repo.archivedItems.single.status, ChallengeStatus.completed);
  });

  testWidgets('Abbrechen setzt zurück', (tester) async {
    final now = DateTime(2026, 10, 10, 12, 0);
    final repo = FakeChallengeRepository(initial: [fasting(started: startAt)]);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(TodayScreen(
        repository: repo,
        clock: () => now,
        onDiscover: () {},
        scheduler: scheduler));
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(repo.items.single.windowStartedAt, isNull);
    expect(find.text('Jetzt starten'), findsOneWidget);
    expect(scheduler.scheduleCalls, 1);
  });
}
