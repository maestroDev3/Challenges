import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/ui/detail_screen.dart';
import 'package:challenges/ui/today_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repository.dart';
import '../support/pump_app.dart';

final now = DateTime(2026, 10, 2, 20);

ActiveChallenge challenge(String templateId, {DateTime? start}) =>
    ActiveChallenge(
      id: templateId,
      template: templateById(templateId)!,
      startedOn: dayOf(start ?? DateTime(2026, 9, 28)),
      reminder: const ReminderTime(7, 0),
    );

final withPlan = challenge('cold-shower')
    .withPlan(when: 'Nach dem Aufstehen', where: 'im Bad');

Future<void> pumpToday(WidgetTester tester, List<ActiveChallenge> items) =>
    tester.pumpApp(TodayScreen(
      repository: FakeChallengeRepository(initial: items, today: now),
      onDiscover: () {},
      clock: () => now,
    ));

void main() {
  testWidgets('Karte auf „Heute“ zeigt den Plan', (tester) async {
    await pumpToday(tester, [withPlan]);
    expect(find.text('Nach dem Aufstehen, im Bad'), findsOneWidget);
  });

  testWidgets('Karte ohne Plan zeigt keine Plan-Zeile', (tester) async {
    await pumpToday(tester, [challenge('cold-shower')]);
    expect(find.byKey(const Key('plan-line')), findsNothing);
  });

  testWidgets('geplante Challenge zeigt den Plan unter „Geplant“',
      (tester) async {
    final planned = challenge('wake-5am', start: DateTime(2026, 10, 5))
        .withPlan(when: 'Nach dem Wecker');
    await pumpToday(tester, [planned]);
    expect(find.text('Geplant'), findsOneWidget);
    expect(find.text('Nach dem Wecker'), findsOneWidget);
  });

  testWidgets('Detailansicht zeigt den Plan', (tester) async {
    await tester.pumpApp(
        ChallengeDetailScreen(challenge: withPlan, clock: () => now));
    expect(find.text('Nach dem Aufstehen, im Bad'), findsOneWidget);
  });
}
