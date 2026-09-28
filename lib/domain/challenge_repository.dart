import 'active_challenge.dart';
import 'challenge.dart';

/// Zugriff auf die laufenden Challenges. Heute lokal, später austauschbar
/// gegen ein Backend (Challenges mit Freunden).
abstract interface class ChallengeRepository {
  Future<List<ActiveChallenge>> active();

  Future<ActiveChallenge?> byId(String id);

  /// Emittiert sofort den aktuellen Stand und danach nach jeder Änderung.
  Stream<List<ActiveChallenge>> watch();

  /// Startet eine Challenge. Läuft die Vorlage bereits, wird die
  /// bestehende Challenge zurückgegeben.
  Future<ActiveChallenge> start(ChallengeTemplate template, ReminderTime reminder);

  Future<void> save(ActiveChallenge challenge);

  Future<void> stop(String id);

  /// Liest den Stand neu (z. B. nach Änderungen aus einer Benachrichtigung
  /// im Hintergrund) und emittiert ihn an `watch()`.
  Future<void> refresh();
}
