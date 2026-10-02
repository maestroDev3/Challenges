import 'package:challenges/data/local_challenge_repository.dart';
import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge_repository.dart';
import 'package:challenges/domain/store_codec.dart';
import 'package:challenges/l10n/app_localizations.dart';
import 'package:challenges/l10n/background_texts.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Freitag, 2. Oktober 2026, 20 Uhr.
final now = DateTime(2026, 10, 2, 20);
final de = lookupAppLocalizations(const Locale('de'));

ActiveChallenge shower() => ActiveChallenge(
      id: 'shower',
      template: templateById('cold-shower')!,
      startedOn: dayOf(now),
      reminder: const ReminderTime(7, 0),
    );

void main() {
  group('Wenn-Dann-Plan', () {
    test('withPlan trimmt beide Teile und macht leere Eingaben zu null', () {
      final c = shower().withPlan(when: '  Nach dem Aufstehen ', where: '   ');
      expect(c.planWhen, 'Nach dem Aufstehen');
      expect(c.planWhere, isNull);
    });

    test('withPlan mit mehr als 60 Zeichen wirft ArgumentError', () {
      final long = 'x' * (maxPlanLength + 1);
      expect(() => shower().withPlan(when: long), throwsArgumentError);
      expect(() => shower().withPlan(where: long), throwsArgumentError);
      expect(shower().withPlan(when: 'x' * maxPlanLength).planWhen,
          hasLength(maxPlanLength));
    });

    test('plan verbindet Zeit und Ort zu einem Satz', () {
      expect(shower().withPlan(when: 'Nach dem Aufstehen', where: 'im Bad').plan,
          'Nach dem Aufstehen, im Bad');
      expect(shower().withPlan(when: 'Nach dem Aufstehen').plan,
          'Nach dem Aufstehen');
      expect(shower().withPlan(where: 'im Bad').plan, 'im Bad');
      expect(shower().plan, isNull);
    });

    test('Plan bleibt bei anderen Änderungen erhalten', () {
      final c = shower()
          .withPlan(when: 'Nach dem Aufstehen', where: 'im Bad')
          .copyWith(reminder: const ReminderTime(6, 30));
      expect(c.plan, 'Nach dem Aufstehen, im Bad');
    });
  });

  group('Speicher', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('start mit planWhen und planWhere speichert den Plan', () async {
      final r = LocalChallengeRepository(await SharedPreferences.getInstance(),
          clock: () => now);
      await r.start(templateById('cold-shower')!, const ReminderTime(7, 0),
          planWhen: 'Nach dem Aufstehen', planWhere: 'im Bad');
      final loaded = (await r.active()).single;
      expect(loaded.plan, 'Nach dem Aufstehen, im Bad');
    });

    test('Plan übersteht Speichern und Laden', () {
      final store = ChallengeStore(active: [
        shower().withPlan(when: 'Nach dem Aufstehen', where: 'im Bad'),
      ]);
      final loaded = decodeStore(encodeStore(store)).active.single;
      expect(loaded.planWhen, 'Nach dem Aufstehen');
      expect(loaded.planWhere, 'im Bad');
    });

    test('alte Daten ohne Plan laden mit leerem Plan', () {
      final text = encodeStore(ChallengeStore(active: [shower()]));
      expect(text, isNot(contains('planWhen')));
      expect(decodeStore(text).active.single.plan, isNull);
    });
  });

  group('Erinnerung', () {
    test('mit Plan ersetzt der Plan die Frage, Knöpfe bleiben', () {
      final t = reminderTexts(de, templateById('cold-shower')!,
          plan: 'Nach dem Aufstehen, im Bad');
      expect(t.body, 'Nach dem Aufstehen, im Bad.');
      expect(t.done, '✓ ${de.commonDone}');
      expect(t.missed, '✗ ${de.commonNotDone}');
    });

    test('ohne Plan bleibt die Frage', () {
      final t = reminderTexts(de, templateById('cold-shower')!);
      expect(t.body, de.reminderAskDone);
    });
  });
}
