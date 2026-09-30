import 'package:challenges/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/fake_scheduler.dart';
import '../support/german_device.dart';

void main() {
  testWidgets('Start plant genau eine Erinnerung, Beenden storniert sie',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeChallengeRepository();
    final scheduler = FakeReminderScheduler();
    useGermanDevice(tester);
    await tester.pumpWidget(
        ChallengesApp(repository: repo, scheduler: scheduler));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Challenge finden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalt duschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Challenge starten'));
    await tester.pumpAndSettle();

    expect(scheduler.scheduleCalls, 1);
    expect(scheduler.scheduled, {repo.items.single.id});

    // zurück auf „Heute“ und über das Menü abschließen
    final id = repo.items.single.id;
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abschließen'));
    await tester.pumpAndSettle();

    expect(scheduler.cancelled, [id]);
    expect(repo.items, isEmpty);
  });
}
