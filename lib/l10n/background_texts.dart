import '../domain/challenge.dart';
import '../domain/csv_export.dart';
import '../domain/reminders.dart';
import '../domain/streak_warning.dart';
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

/// Mit Wenn-Dann-[plan] ersetzt der Plan die Standardfrage.
ReminderTexts reminderTexts(
  AppLocalizations l10n,
  ChallengeTemplate template, {
  String? plan,
}) =>
    (
      title: '${template.emoji} ${template.titleIn(l10n)}',
      body: switch (reminderActionsFor(template.kind)) {
        _ when plan != null => '$plan.',
        ReminderActions.journalInput => l10n.journalPrompt,
        ReminderActions.none => l10n.reminderEnterMinutes,
        ReminderActions.doneMissed => l10n.reminderAskDone,
      },
      done: '✓ ${l10n.commonDone}',
      missed: '✗ ${l10n.commonNotDone}',
      journalAction: l10n.reminderJournalAction,
      journalInput: l10n.reminderJournalInput,
    );

/// Titel und Text der abendlichen Warnung; die Knöpfe kommen aus
/// [reminderTexts].
({String title, String body}) streakWarningTexts(
  AppLocalizations l10n,
  StreakWarning warning,
) {
  final title = warning.challenge.template.titleIn(l10n);
  if (warning
      case StreakWarning(weeklyDone: final d?, weeklyTarget: final t?)) {
    return (
      title: l10n.streakWarningWeeklyTitle(title),
      body: l10n.streakWarningWeeklyBody(d, t),
    );
  }
  return (
    title: l10n.streakWarningTitle(warning.streak),
    body: warning.jokerAvailable
        ? l10n.streakWarningJokerBody(title)
        : l10n.streakWarningBody(title),
  );
}

/// Texte der CSV-Tabelle in der gewählten Sprache.
CsvTexts csvTextsFor(AppLocalizations l10n) => CsvTexts(
      header: l10n.csvHeader,
      done: l10n.statusDone,
      missed: l10n.csvMissed,
      title: (template) => template.titleIn(l10n),
    );
