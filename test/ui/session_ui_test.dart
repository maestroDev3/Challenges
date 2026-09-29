import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/pump_app.dart';

final t0 = DateTime(2026, 10, 7, 20, 0);

ActiveChallenge eyeGaze({DateTime? session}) {
  final c = ActiveChallenge(
    id: 'eye',
    template: templateById('eye-gaze')!,
    startedOn: dayOf(t0),
    reminder: const ReminderTime(20, 0),
  );
  return session == null ? c : c.startSession(session);
}

void main() {
  testWidgets('„Starten“ startet die Stoppuhr mit laufender Benachrichtigung',
      (tester) async {
    final repo = FakeChallengeRepository(initial: [eyeGaze()]);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(TodayScreen(
        repository: repo, clock: () => t0, onDiscover: () {}, scheduler: scheduler));
    expect(find.text('Ziel: 10 min'), findsOneWidget);
    await tester.tap(find.text('Starten'));
    await tester.pumpAndSettle();
    expect(repo.items.single.sessionStartedAt, t0);
    expect(scheduler.sessionsShown, ['eye']);
    expect(find.text('Stopp'), findsOneWidget);
  });

  testWidgets('Karte zeigt die laufende Zeit live', (tester) async {
    var now = t0.add(const Duration(minutes: 3, seconds: 5));
    final repo = FakeChallengeRepository(initial: [eyeGaze(session: t0)]);
    await tester.pumpApp(TodayScreen(
        repository: repo, clock: () => now, onDiscover: () {}));
    expect(find.text('03:05 / 10:00'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('03:06 / 10:00'), findsOneWidget);
  });

  testWidgets('Stopp nach 10 min hakt ab und beendet die Benachrichtigung',
      (tester) async {
    final now = t0.add(const Duration(minutes: 10, seconds: 20));
    final repo = FakeChallengeRepository(initial: [eyeGaze(session: t0)]);
    final scheduler = FakeReminderScheduler();
    await tester.pumpApp(TodayScreen(
        repository: repo, clock: () => now, onDiscover: () {}, scheduler: scheduler));
    await tester.tap(find.text('Stopp'));
    await tester.pumpAndSettle();
    expect(repo.items.single.sessionStartedAt, isNull);
    expect(repo.items.single.checkInOn(now)!.status, CheckInStatus.done);
    expect(scheduler.sessionsCleared, ['eye']);
  });
}
