import 'active_challenge.dart';
import 'challenge.dart';

const challengeCatalog = <ChallengeTemplate>[
  ChallengeTemplate(
    id: 'wake-5am',
    title: 'Um 5 Uhr aufstehen',
    description:
        '30 Tage lang um 5:00 Uhr aufstehen – ohne Snooze. Wecker klingelt, Füße auf den Boden.',
    emoji: '⏰',
    kind: DailyKind(days: 30),
  ),
  ChallengeTemplate(
    id: 'morning-routine',
    title: 'Tägliche Morgenroutine',
    description:
        '30 Tage lang jeden Morgen deine feste Routine durchziehen, bevor der Tag dich übernimmt.',
    emoji: '🌅',
    kind: DailyKind(days: 30),
  ),
  ChallengeTemplate(
    id: 'cold-shower',
    title: 'Kalt duschen',
    description:
        '30 Tage kalt duschen – und am Ende nicht doch noch warm aufdrehen.',
    emoji: '🧊',
    kind: DailyKind(days: 30),
  ),
  ChallengeTemplate(
    id: 'no-sugar',
    title: '21 Tage ohne Zucker',
    description:
        'Kein Zucker in jeder Form: keine Süßigkeiten, keine süßen Getränke, kein versteckter Zucker.',
    emoji: '🚫',
    kind: DailyKind(days: 21),
  ),
  ChallengeTemplate(
    id: 'meditate-sleep',
    title: 'Meditieren vor dem Schlafen',
    description: 'Jeden Abend vor dem Einschlafen bewusst zur Ruhe kommen.',
    emoji: '🧘',
    kind: DailyKind(),
  ),
  ChallengeTemplate(
    id: 'eye-gaze',
    title: '10 min in die eigenen Augen schauen',
    description:
        'Zehn Minuten in den Spiegel und dir selbst in die Augen schauen. Aushalten, nicht wegsehen.',
    emoji: '👁️',
    kind: DailyKind(),
  ),
  ChallengeTemplate(
    id: 'excuse-journal',
    title: 'Ausreden aufschreiben',
    description:
        'Schreib auf, warum du etwas nicht gemacht hast. Ehrlich – nur für dich.',
    emoji: '📝',
    kind: JournalKind(),
  ),
  ChallengeTemplate(
    id: 'nature-2h',
    title: '2 h pro Woche in der Natur',
    description:
        'Jede Woche zwei Stunden draußen in der Natur – ohne Handy, ohne Kopfhörer.',
    emoji: '🌲',
    kind: WeeklyGoalKind(120),
  ),
  ChallengeTemplate(
    id: 'fasting-24h',
    title: '24 h Diät',
    description:
        '24 Stunden fasten: nur Wasser, Tee oder schwarzer Kaffee. Bei Vorerkrankungen vorher ärztlich abklären.',
    emoji: '🍽️',
    kind: OneTimeKind(Duration(hours: 24)),
  ),
  ChallengeTemplate(
    id: 'silence-24h',
    title: '24 h nicht sprechen',
    description: 'Einen ganzen Tag lang kein Wort sagen. Zuhören statt reden.',
    emoji: '🤐',
    kind: OneTimeKind(Duration(hours: 24)),
  ),
  ChallengeTemplate(
    id: 'book-in-a-day',
    title: 'Ein Buch an einem Tag',
    description: 'Ein komplettes Buch an einem einzigen Tag durchlesen.',
    emoji: '📖',
    kind: OneTimeKind(Duration(hours: 24)),
  ),
];

ChallengeTemplate? templateById(String id) {
  for (final t in challengeCatalog) {
    if (t.id == id) return t;
  }
  return null;
}

/// Sinnvolle Standard-Uhrzeit für die Erinnerung je Challenge.
ReminderTime defaultReminderFor(String templateId) => switch (templateId) {
      'wake-5am' => const ReminderTime(5, 0),
      'morning-routine' => const ReminderTime(6, 0),
      'cold-shower' => const ReminderTime(7, 0),
      'eye-gaze' => const ReminderTime(20, 0),
      'excuse-journal' => const ReminderTime(21, 0),
      'meditate-sleep' => const ReminderTime(22, 0),
      'nature-2h' => const ReminderTime(18, 0),
      _ => const ReminderTime(9, 0),
    };
