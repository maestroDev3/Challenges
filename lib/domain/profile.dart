import 'active_challenge.dart';
import 'challenge_repository.dart';
import 'milestones.dart';

/// Kennzahlen über alle Challenges hinweg für die Profil-Übersicht.
typedef ProfileStats = ({
  int started,
  int running,
  int completed,
  int doneDays,
  int longestStreak,
  int badges,
});

/// Fasst den gesamten Stand zusammen. Beendete (nicht geschaffte)
/// Challenges zählen bei Tagen und Streak mit, aber nicht als geschafft.
ProfileStats profileStats(ChallengeStore store) {
  final all = [...store.active, ...store.archived];
  var longest = 0;
  for (final challenge in all) {
    if (challenge.bestStreak > longest) longest = challenge.bestStreak;
  }
  return (
    started: all.length,
    running: store.active.length,
    completed: store.archived
        .where((c) => c.status == ChallengeStatus.completed)
        .length,
    doneDays: all.fold(0, (sum, c) => sum + c.doneDays),
    longestStreak: longest,
    badges: all.fold(0, (sum, c) => sum + badges(c).length),
  );
}

extension ProfileStatsEmpty on ProfileStats {
  /// Noch nie eine Challenge gestartet.
  bool get isEmpty => started == 0;
}
