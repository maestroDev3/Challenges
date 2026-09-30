import '../domain/challenge.dart';
import '../domain/csv_export.dart';
import '../domain/reminders.dart';
import 'app_localizations.dart';
import 'template_text.dart';

/// Texte einer Erinnerung in der gewählten Sprache – auch für den
/// Hintergrund, wo es keinen `BuildContext` gibt.
typedef ReminderTexts = ({
  String title,
  String body,
  String done,
  String missed,
  String journalAction,
  String journalInput,
});

ReminderTexts reminderTexts(AppLocalizations l10n, ChallengeTemplate template) =>
    (
      title: '${template.emoji} ${template.titleIn(l10n)}',
      body: switch (reminderActionsFor(template.kind)) {
        ReminderActions.journalInput => l10n.journalPrompt,
        ReminderActions.none => l10n.reminderEnterMinutes,
        ReminderActions.doneMissed => l10n.reminderAskDone,
      },
      done: '✓ ${l10n.commonDone}',
      missed: '✗ ${l10n.commonNotDone}',
      journalAction: l10n.reminderJournalAction,
      journalInput: l10n.reminderJournalInput,
    );

/// Texte der CSV-Tabelle in der gewählten Sprache.
CsvTexts csvTextsFor(AppLocalizations l10n) => CsvTexts(
      header: l10n.csvHeader,
      done: l10n.statusDone,
      missed: l10n.csvMissed,
      title: (template) => template.titleIn(l10n),
    );
