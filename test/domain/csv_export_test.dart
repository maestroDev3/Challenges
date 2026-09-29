import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/challenge_repository.dart';
import 'package:challenges/domain/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

const bom = '﻿';
const header = 'Datum;Challenge;Status;Minuten;Notiz';

ActiveChallenge challenge(String id, ChallengeTemplate t) => ActiveChallenge(
      id: id,
      template: t,
      startedOn: DateTime.utc(2026, 9, 1),
      reminder: const ReminderTime(7, 0),
    );

List<String> lines(String csv) {
  expect(csv.startsWith(bom), isTrue);
  return csv.substring(1).split('\r\n')..removeWhere((l) => l.isEmpty);
}

void main() {
  group('exportCsv', () {
    test('ohne Check-ins entsteht nur die Kopfzeile mit BOM', () {
      expect(lines(exportCsv(const ChallengeStore())), [header]);
    });

    test('eine Zeile pro Check-in aus aktiven und archivierten Challenges, sortiert',
        () {
      final shower = challenge('a', templateById('cold-shower')!)
          .checkIn(DateTime(2026, 9, 3), CheckInStatus.done)
          .checkIn(DateTime(2026, 9, 2), CheckInStatus.missed);
      final nature = challenge('b', templateById('nature-2h')!)
          .checkIn(DateTime(2026, 9, 2), CheckInStatus.done, minutes: 45)
          .finish(DateTime(2026, 9, 4));
      final csv = exportCsv(ChallengeStore(active: [shower], archived: [nature]));
      expect(lines(csv), [
        header,
        '2026-09-02;2 h pro Woche in der Natur;erledigt;45;',
        '2026-09-02;Kalt duschen;nicht erledigt;;',
        '2026-09-03;Kalt duschen;erledigt;;',
      ]);
    });

    test('Sonderzeichen werden in Anführungszeichen gesetzt', () {
      final t = ChallengeTemplate.custom(
          title: 'Lesen; täglich', kind: const JournalKind());
      final c = challenge('c', t).checkIn(
          DateTime(2026, 9, 5), CheckInStatus.done,
          note: 'Er sagte "morgen"\nund ging');
      expect(lines(exportCsv(ChallengeStore(active: [c]))), [
        header,
        '2026-09-05;"Lesen; täglich";erledigt;;"Er sagte ""morgen""\nund ging"',
      ]);
    });
  });
}
