import 'active_challenge.dart';
import 'challenge.dart';

/// Streak-Längen (in Tagen), die gefeiert werden.
const milestones = [7, 21, 30, 66, 100];

/// Neuer Meilenstein durch die Änderung von [before] zu [after] – oder null.
/// Maßgeblich ist die beste Streak, damit jeder Meilenstein nur einmal
/// gefeiert wird (auch nach einem Neustart). Nur für tägliche Challenges.
int? milestoneReached(ActiveChallenge before, ActiveChallenge after) {
  if (after.kind is! DailyKind && after.kind is! JournalKind) return null;
  final was = before.bestStreak, now = after.bestStreak;
  int? reached;
  for (final m in milestones) {
    if (was < m && now >= m) reached = m;
  }
  return reached;
}

/// Erreichte Abzeichen (Meilensteine bis zur besten Streak).
List<int> badges(ActiveChallenge c) => (c.kind is DailyKind || c.kind is JournalKind)
    ? [for (final m in milestones) if (c.bestStreak >= m) m]
    : const [];

/// Der nächste Meilenstein: Länge, verbleibende Tage und der Tag, an dem er
/// bei lückenloser Serie fällt.
typedef NextMilestone = ({int days, int remaining, DateTime date});

/// Nächster Meilenstein ab der aktuellen Serie – oder null bei einmaligen
/// und Wochenziel-Challenges, nach 100 Tagen oder wenn das Ziel einer
/// X-Tage-Challenge vorher erreicht ist.
NextMilestone? nextMilestone(ActiveChallenge c, DateTime today) {
  final kind = c.kind;
  if (kind is! DailyKind && kind is! JournalKind) return null;
  final t = dayOf(today);
  final streak = c.currentStreak(t);
  final todayDone = c.checkInOn(t)?.status == CheckInStatus.done;
  for (final m in milestones) {
    if (streak >= m) continue;
    if (kind case DailyKind(days: final goal?) when m > goal) return null;
    final remaining = m - streak;
    return (
      days: m,
      remaining: remaining,
      date: t.add(Duration(days: todayDone ? remaining : remaining - 1)),
    );
  }
  return null;
}
