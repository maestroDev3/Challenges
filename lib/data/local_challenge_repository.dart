import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';
import '../domain/store_codec.dart';

/// Speichert alles als JSON in shared_preferences.
///
/// Format v2: `{version, templates: [...], challenges: [...]}`. Daten aus v1
/// (nur aktive Katalog-Challenges) werden beim Lesen übernommen.
class LocalChallengeRepository implements ChallengeRepository {
  LocalChallengeRepository(this._prefs, {Clock? clock})
      : _clock = clock ?? DateTime.now;

  static const _keyV1 = 'active_challenges_v1';
  static const _keyV2 = 'challenges_v2';

  final SharedPreferences _prefs;
  final Clock _clock;
  final _changes = StreamController<ChallengeStore>.broadcast();

  // ---------- Lesen ----------

  Future<ChallengeStore> _load() async {
    // Hintergrund-Isolate (Benachrichtigungs-Aktionen) schreiben ebenfalls.
    await _prefs.reload();
    final raw = _prefs.getString(_keyV2);
    if (raw != null) return decodeStore(raw);
    final legacy = _prefs.getString(_keyV1);
    return legacy == null ? const ChallengeStore() : decodeLegacyStore(legacy);
  }

  @override
  Future<List<ActiveChallenge>> active() async => (await _load()).active;

  @override
  Future<List<ActiveChallenge>> archived() async => (await _load()).archived;

  @override
  Future<List<ChallengeTemplate>> customTemplates() async =>
      (await _load()).customTemplates;

  @override
  Future<ActiveChallenge?> byId(String id) async {
    final store = await _load();
    for (final c in [...store.active, ...store.archived]) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Stream<List<ActiveChallenge>> watch() => watchStore().map((s) => s.active);

  @override
  Stream<ChallengeStore> watchStore() async* {
    yield await _load();
    yield* _changes.stream;
  }

  @override
  Future<void> refresh() async => _changes.add(await _load());

  // ---------- Schreiben ----------

  @override
  Future<ActiveChallenge> start(
    ChallengeTemplate template,
    ReminderTime reminder, {
    StreakRule rule = StreakRule.relaxed,
    DateTime? startOn,
  }) async {
    final now = _clock();
    final startDay = _checkedStart(startOn, now);
    final store = await _load();
    for (final c in store.active) {
      if (c.template.id == template.id) return c;
    }
    final taken = {for (final c in [...store.active, ...store.archived]) c.id};
    final base = '${template.id}-${now.microsecondsSinceEpoch}';
    var id = base;
    for (var n = 2; taken.contains(id); n++) {
      id = '$base-$n';
    }
    final c = ActiveChallenge(
      id: id,
      template: template,
      startedOn: startDay,
      reminder: reminder,
      rule: ruleFor(template.kind, rule),
    );
    await _write(store, active: [...store.active, c]);
    return c;
  }

  @override
  Future<void> save(ActiveChallenge challenge) async {
    final store = await _load();
    await _write(
      store,
      active: [
        for (final c in store.active)
          if (c.id != challenge.id) c else if (!challenge.isArchived) challenge,
      ],
      archived: [
        for (final c in store.archived)
          if (c.id != challenge.id) c,
        if (challenge.isArchived) challenge,
      ],
    );
  }

  @override
  Future<ActiveChallenge?> finish(String id) async {
    final store = await _load();
    for (final c in store.active) {
      if (c.id == id) {
        final done = c.finish(_clock());
        await _write(
          store,
          active: [for (final a in store.active) if (a.id != id) a],
          archived: [...store.archived, done],
        );
        return done;
      }
    }
    return null;
  }

  @override
  Future<ActiveChallenge> reopen(String id) async {
    final store = await _load();
    final archived = store.archived.where((c) => c.id == id).firstOrNull;
    if (archived == null) throw StateError('Challenge ist nicht archiviert');
    if (store.active.any((c) => c.template.id == archived.template.id)) {
      throw StateError('Dieselbe Vorlage läuft bereits');
    }
    final reopened = archived.reopen();
    await _write(
      store,
      active: [...store.active, reopened],
      archived: [for (final c in store.archived) if (c.id != id) c],
    );
    return reopened;
  }

  @override
  Future<void> delete(String id) async {
    final store = await _load();
    await _write(
      store,
      active: [for (final c in store.active) if (c.id != id) c],
      archived: [for (final c in store.archived) if (c.id != id) c],
    );
  }

  @override
  Future<void> saveTemplate(ChallengeTemplate template) async {
    final store = await _load();
    final exists = store.customTemplates.any((t) => t.id == template.id);
    await _write(
      store,
      templates: exists
          ? [
              for (final t in store.customTemplates)
                t.id == template.id ? template : t,
            ]
          : [...store.customTemplates, template],
      active: [
        for (final c in store.active)
          c.template.id == template.id ? c.copyWith(template: template) : c,
      ],
    );
  }

  @override
  Future<void> deleteTemplate(String id) async {
    final store = await _load();
    if (store.active.any((c) => c.template.id == id)) {
      throw StateError('Vorlage wird von einer laufenden Challenge genutzt');
    }
    await _write(store,
        templates: [for (final t in store.customTemplates) if (t.id != id) t]);
  }

  @override
  Future<void> replaceAll(ChallengeStore store) => _write(
        const ChallengeStore(),
        active: store.active,
        archived: store.archived,
        templates: store.customTemplates,
      );

  Future<void> _write(
    ChallengeStore store, {
    List<ActiveChallenge>? active,
    List<ActiveChallenge>? archived,
    List<ChallengeTemplate>? templates,
  }) async {
    final next = ChallengeStore(
      active: active ?? store.active,
      archived: archived ?? store.archived,
      customTemplates: templates ?? store.customTemplates,
    );
    await _prefs.setString(_keyV2, encodeStore(next));
    await _prefs.remove(_keyV1);
    _changes.add(next);
  }

  /// Starttag: heute oder geplant bis [maxPlanDays] voraus.
  DateTime _checkedStart(DateTime? startOn, DateTime now) {
    final today = dayOf(now);
    final day = dayOf(startOn ?? now);
    final days = day.difference(today).inDays;
    if (days < 0 || days > maxPlanDays) {
      throw ArgumentError.value(startOn, 'startOn', 'heute bis $maxPlanDays Tage voraus');
    }
    return day;
  }
}
