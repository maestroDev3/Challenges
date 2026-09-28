import 'package:challenges/data/local_challenge_repository.dart';
import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime(2026, 10, 5, 8, 30);

Future<LocalChallengeRepository> newRepo() async =>
    LocalChallengeRepository(await SharedPreferences.getInstance(),
        clock: () => now);

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('start legt aktive Challenge an', () async {
    final repo = await newRepo();
    final c = await repo.start(
        templateById('wake-5am')!, const ReminderTime(5, 0));
    expect(c.template.id, 'wake-5am');
    expect(c.reminder, const ReminderTime(5, 0));
    expect(c.startedOn, dayOf(now));
    final active = await repo.active();
    expect(active.map((a) => a.id), [c.id]);
  });

  test('start derselben Vorlage liefert die bestehende Challenge', () async {
    final repo = await newRepo();
    final a = await repo.start(
        templateById('wake-5am')!, const ReminderTime(5, 0));
    final b = await repo.start(
        templateById('wake-5am')!, const ReminderTime(6, 0));
    expect(b.id, a.id);
    expect(await repo.active(), hasLength(1));
  });

  test('save persistiert Check-ins über Instanzen hinweg', () async {
    final repo = await newRepo();
    var c = await repo.start(
        templateById('nature-2h')!, const ReminderTime(18, 15));
    c = c.checkIn(now, CheckInStatus.done, minutes: 40, note: 'Wald');
    await repo.save(c);

    final reloaded = (await (await newRepo()).active()).single;
    expect(reloaded.id, c.id);
    expect(reloaded.template.id, 'nature-2h');
    expect(reloaded.reminder, const ReminderTime(18, 15));
    expect(reloaded.startedOn, dayOf(now));
    final ci = reloaded.checkInOn(now)!;
    expect(ci.status, CheckInStatus.done);
    expect(ci.minutes, 40);
    expect(ci.note, 'Wald');
  });

  test('byId findet Challenge oder null', () async {
    final repo = await newRepo();
    final c = await repo.start(
        templateById('cold-shower')!, const ReminderTime(7, 0));
    expect((await repo.byId(c.id))?.id, c.id);
    expect(await repo.byId('gibt-es-nicht'), isNull);
  });

  test('stop entfernt die Challenge', () async {
    final repo = await newRepo();
    final c = await repo.start(
        templateById('cold-shower')!, const ReminderTime(7, 0));
    await repo.stop(c.id);
    expect(await repo.active(), isEmpty);
  });

  test('watch emittiert aktuellen Stand und jede Änderung', () async {
    final repo = await newRepo();
    final lengths = <int>[];
    final sub = repo.watch().listen((l) => lengths.add(l.length));
    await settle();
    final c = await repo.start(
        templateById('cold-shower')!, const ReminderTime(7, 0));
    await settle();
    await repo.stop(c.id);
    await settle();
    await sub.cancel();
    expect(lengths, [0, 1, 0]);
  });
}
