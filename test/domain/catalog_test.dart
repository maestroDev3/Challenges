import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

ChallengeTemplate byId(String id) =>
    challengeCatalog.firstWhere((t) => t.id == id);

void main() {
  test('Katalog enthält genau 11 Vorlagen mit eindeutigen ids', () {
    expect(challengeCatalog, hasLength(11));
    expect(challengeCatalog.map((t) => t.id).toSet(), hasLength(11));
  });

  test('alle Vorlagen haben Titel, Beschreibung und Emoji', () {
    for (final t in challengeCatalog) {
      expect(t.title, isNotEmpty, reason: t.id);
      expect(t.description, isNotEmpty, reason: t.id);
      expect(t.emoji, isNotEmpty, reason: t.id);
    }
  });

  test('30-Tage-Challenges', () {
    for (final id in ['wake-5am', 'morning-routine', 'cold-shower']) {
      final kind = byId(id).kind;
      expect(kind, isA<DailyKind>(), reason: id);
      expect((kind as DailyKind).days, 30, reason: id);
    }
  });

  test('21 Tage ohne Zucker', () {
    final kind = byId('no-sugar').kind;
    expect(kind, isA<DailyKind>());
    expect((kind as DailyKind).days, 21);
  });

  test('einmalige 24-h-Challenges', () {
    for (final id in ['fasting-24h', 'silence-24h', 'book-in-a-day']) {
      final kind = byId(id).kind;
      expect(kind, isA<OneTimeKind>(), reason: id);
      expect((kind as OneTimeKind).window, const Duration(hours: 24),
          reason: id);
    }
  });

  test('Natur ohne Handy ist Wochenziel mit 120 Minuten', () {
    final kind = byId('nature-2h').kind;
    expect(kind, isA<WeeklyGoalKind>());
    expect((kind as WeeklyGoalKind).minutes, 120);
  });

  test('Ausreden aufschreiben ist Journal', () {
    expect(byId('excuse-journal').kind, isA<JournalKind>());
  });

  test('offene tägliche Challenges', () {
    for (final id in ['meditate-sleep', 'eye-gaze']) {
      final kind = byId(id).kind;
      expect(kind, isA<DailyKind>(), reason: id);
      expect((kind as DailyKind).days, isNull, reason: id);
    }
  });
}
