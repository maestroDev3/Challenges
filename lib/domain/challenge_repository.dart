import 'active_challenge.dart';
import 'challenge.dart';

/// Gesamter gespeicherter Stand.
class ChallengeStore {
  const ChallengeStore({
    this.active = const [],
    this.archived = const [],
    this.customTemplates = const [],
  });

  final List<ActiveChallenge> active;
  final List<ActiveChallenge> archived;
  final List<ChallengeTemplate> customTemplates;
}

/// Zugriff auf Challenges und eigene Vorlagen. Heute lokal, später
/// austauschbar gegen ein Backend (Challenges mit Freunden).
abstract interface class ChallengeRepository {
  Future<List<ActiveChallenge>> active();

  Future<List<ActiveChallenge>> archived();

  /// Sucht aktive und archivierte Challenges.
  Future<ActiveChallenge?> byId(String id);

  /// Aktive Challenges: sofort der aktuelle Stand, danach jede Änderung.
  Stream<List<ActiveChallenge>> watch();

  /// Gesamter Stand: sofort, danach jede Änderung.
  Stream<ChallengeStore> watchStore();

  /// Startet eine Challenge. Läuft die Vorlage bereits, wird die
  /// laufende Challenge zurückgegeben.
  Future<ActiveChallenge> start(
    ChallengeTemplate template,
    ReminderTime reminder, {
    StreakRule rule = StreakRule.relaxed,
  });

  Future<void> save(ActiveChallenge challenge);

  /// Archiviert die Challenge (geschafft oder beendet).
  Future<ActiveChallenge?> finish(String id);

  /// Entfernt eine aktive oder archivierte Challenge endgültig.
  Future<void> delete(String id);

  Future<List<ChallengeTemplate>> customTemplates();

  /// Legt eine eigene Vorlage an oder ändert sie (auch in laufenden Challenges).
  Future<void> saveTemplate(ChallengeTemplate template);

  /// Löscht eine eigene Vorlage. Wirft [StateError], wenn eine aktive
  /// Challenge sie nutzt.
  Future<void> deleteTemplate(String id);

  /// Liest den Stand neu (z. B. nach Änderungen aus einer Benachrichtigung
  /// im Hintergrund) und emittiert ihn.
  Future<void> refresh();
}
