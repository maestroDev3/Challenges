import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/catalog.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/challenge_repository.dart';
import 'package:challenges/domain/csv_export.dart';
import 'package:challenges/domain/widget_data.dart';
import 'package:challenges/l10n/app_localizations.dart';
import 'package:challenges/l10n/background_texts.dart';
import 'package:challenges/l10n/template_text.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final en = lookupAppLocalizations(const Locale('en'));
final ru = lookupAppLocalizations(const Locale('ru'));
final today = DateTime(2026, 10, 9);

ActiveChallenge running(String templateId) => ActiveChallenge(
      id: templateId,
      template: templateById(templateId)!,
      startedOn: DateTime(2026, 10, 5),
      reminder: const ReminderTime(7, 0),
    );

void main() {
  group('reminderTexts', () {
    test('Erinnerung mit Erledigt/Nicht erledigt auf Englisch', () {
      final t = reminderTexts(en, templateById('wake-5am')!);
      expect(t.title, '⏰ Wake up at 5 am');
      expect(t.body, 'Did you make it today?');
      expect(t.done, '✓ Done');
      expect(t.missed, '✗ Not done');
    });

    test('Tagebuch: Frage, Aktion und Eingabe auf Englisch', () {
      final t = reminderTexts(en, templateById('excuse-journal')!);
      expect(t.body, 'What excuse did you have today?');
      expect(t.journalAction, 'Write it down');
      expect(t.journalInput, 'Your excuse');
    });

    test('Russisch', () {
      final t = reminderTexts(ru, templateById('cold-shower')!);
      expect(t.title, '🧊 Холодный душ');
      expect(t.body, 'Получилось сегодня?');
    });

    test('eigene Vorlage behält ihren Titel', () {
      final own = ChallengeTemplate.custom(
          title: 'Lesen', emoji: '📚', kind: const DailyKind());
      expect(reminderTexts(en, own).title, '📚 Lesen');
    });
  });

  test('CSV auf Englisch: Kopfzeile, Status und Vorlagentitel', () {
    final shower = running('cold-shower')
        .checkIn(DateTime(2026, 10, 6), CheckInStatus.done);
    final csv =
        exportCsv(ChallengeStore(active: [shower]), texts: csvTextsFor(en));
    final lines = csv.substring(1).split('\r\n');
    expect(lines[0], 'Date;Challenge;Status;Minutes;Note');
    expect(lines[1], '2026-10-06;Cold showers;done;;');
  });

  test('Widget-Zeilen mit übersetztem Titel', () {
    final entries = widgetEntries([running('cold-shower')], today,
        titleOf: (t) => t.titleIn(en));
    expect(entries.single.title, '🧊 Cold showers');
  });

  test('Widget ohne Übersetzung bleibt beim gespeicherten Titel', () {
    expect(widgetEntries([running('cold-shower')], today).single.title,
        '🧊 Kalt duschen');
  });
}
