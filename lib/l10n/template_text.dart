import '../domain/challenge.dart';
import 'app_localizations.dart';
import 'dates.dart';

/// Anzeige-Texte einer Vorlage in der gewählten Sprache. Gespeichert bleibt
/// immer der deutsche Text; Katalog-Vorlagen werden über ihre ID übersetzt,
/// eigene Vorlagen zeigen den Text des Nutzers unverändert.
extension TemplateText on ChallengeTemplate {
  String titleIn(AppLocalizations l10n) =>
      _catalogText(l10n)?.title ?? title;

  String descriptionIn(AppLocalizations l10n) =>
      _catalogText(l10n)?.description ?? description;

  List<String> stepsIn(AppLocalizations l10n) => switch (id) {
        'morning-routine' when steps.length == 4 => [
            l10n.tplMorningRoutineStep1,
            l10n.tplMorningRoutineStep2,
            l10n.tplMorningRoutineStep3,
            l10n.tplMorningRoutineStep4,
          ],
        _ => steps,
      };

  ({String title, String description})? _catalogText(AppLocalizations l10n) =>
      switch (id) {
        'wake-5am' => (
            title: l10n.tplWake5amTitle,
            description: l10n.tplWake5amDescription
          ),
        'morning-routine' => (
            title: l10n.tplMorningRoutineTitle,
            description: l10n.tplMorningRoutineDescription
          ),
        'cold-shower' => (
            title: l10n.tplColdShowerTitle,
            description: l10n.tplColdShowerDescription
          ),
        'no-sugar' => (
            title: l10n.tplNoSugarTitle,
            description: l10n.tplNoSugarDescription
          ),
        'meditate-sleep' => (
            title: l10n.tplMeditateSleepTitle,
            description: l10n.tplMeditateSleepDescription
          ),
        'eye-gaze' => (
            title: l10n.tplEyeGazeTitle,
            description: l10n.tplEyeGazeDescription
          ),
        'excuse-journal' => (
            title: l10n.tplExcuseJournalTitle,
            description: l10n.tplExcuseJournalDescription
          ),
        'nature-2h' => (
            title: l10n.tplNature2hTitle,
            description: l10n.tplNature2hDescription
          ),
        'fasting-24h' => (
            title: l10n.tplFasting24hTitle,
            description: l10n.tplFasting24hDescription
          ),
        'silence-24h' => (
            title: l10n.tplSilence24hTitle,
            description: l10n.tplSilence24hDescription
          ),
        'book-in-a-day' => (
            title: l10n.tplBookInADayTitle,
            description: l10n.tplBookInADayDescription
          ),
        _ => null,
      };
}

/// Kurzbeschreibung der Art, z. B. „30 Tage“, „3×/Woche · Mo Mi Fr“.
String kindLabelIn(AppLocalizations l10n, ChallengeKind kind) => switch (kind) {
      DailyKind(days: final d?) => l10n.daysCount(d),
      DailyKind() => l10n.kindDaily,
      OneTimeKind(date: final d?) => l10n.kindOneTimeOn(formatDate(l10n, d)),
      OneTimeKind(window: final w) => l10n.kindWindowHours(w.inHours),
      WeeklyGoalKind(unit: WeeklyUnit.times, target: final n, weekdays: final w)
          when w.isNotEmpty =>
        '${l10n.kindTimesPerWeek(n)} · '
            '${([...w]..sort()).map((d) => weekdayShort(l10n, d)).join(' ')}',
      WeeklyGoalKind(unit: WeeklyUnit.times, target: final n) =>
        l10n.kindTimesPerWeek(n),
      WeeklyGoalKind(target: final m) => m % 60 == 0
          ? l10n.kindHoursPerWeek(m ~/ 60)
          : l10n.kindMinutesPerWeek(m),
      JournalKind() => l10n.kindJournal,
    };
