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
