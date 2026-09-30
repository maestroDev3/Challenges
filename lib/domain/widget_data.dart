import 'active_challenge.dart';
import 'challenge.dart';
import 'challenge_repository.dart';

/// Höchstens so viele Challenges zeigt das Homescreen-Widget.
const maxWidgetEntries = 4;

/// Eine Zeile im Homescreen-Widget.
class WidgetEntry {
  const WidgetEntry({
    required this.id,
    required this.title,
    required this.streak,
    required this.doneToday,
  });

  final String id;
  final String title;
  final String streak;
  final bool doneToday;
}

/// Bereitet die aktiven Challenges für das Widget auf: pausierte und geplante fehlen,
/// offene stehen vor erledigten, höchstens [maxWidgetEntries]. [titleOf]
/// liefert den Anzeigenamen (übersetzt), sonst gilt der gespeicherte Titel.
List<WidgetEntry> widgetEntries(
  List<ActiveChallenge> active,
  DateTime today, {
  String Function(ChallengeTemplate template)? titleOf,
}) {
  final entries = [
    for (final c in active)
      if (!c.isArchived && !c.isPaused(today) && !c.isUpcoming(today))
        WidgetEntry(
          id: c.id,
          title: '${c.template.emoji} '
              '${titleOf?.call(c.template) ?? c.template.title}',
          streak: '🔥 ${c.currentStreak(today)}',
          doneToday: c.checkInOn(today)?.status == CheckInStatus.done,
        ),
  ];
  // Stabile Sortierung: offene zuerst, sonst Reihenfolge der App.
  final open = [for (final e in entries) if (!e.doneToday) e];
  final done = [for (final e in entries) if (e.doneToday) e];
  return [...open, ...done].take(maxWidgetEntries).toList();
}

/// Aktualisiert das Homescreen-Widget (Plattform-Implementierung in lib/data).
abstract interface class WidgetUpdater {
  Future<void> update(List<ActiveChallenge> active, DateTime today);
}

/// Verarbeitet einen Tipp auf den Haken im Widget (`ritual://check?id=…`).
/// Gibt true zurück, wenn ein Check-in gespeichert wurde.
Future<bool> handleWidgetTap(
  ChallengeRepository repository,
  Uri? uri, {
  required DateTime now,
}) async {
  final id = uri?.queryParameters['id'];
  if (uri?.host != 'check' || id == null) return false;
  final c = await repository.byId(id);
  if (c == null || c.isArchived) return false;
  if (c.checkInOn(now)?.status == CheckInStatus.done) return false;
  final updated = c.checkIn(now, CheckInStatus.done);
  await repository.save(updated);
  if (updated.shouldAutoFinish(now)) await repository.finish(updated.id);
  return true;
}
