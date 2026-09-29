import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/active_challenge.dart';
import '../domain/catalog.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';

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
    if (raw == null) return _loadV1();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final templates = [
      for (final t in (json['templates'] as List).cast<Map<String, dynamic>>())
        _templateFromJson(t),
    ];
    final byId = {for (final t in templates) t.id: t};
    final challenges = [
      for (final c in (json['challenges'] as List).cast<Map<String, dynamic>>())
        ?_challengeFromJson(c, byId),
    ];
    return ChallengeStore(
      active: [for (final c in challenges) if (!c.isArchived) c],
      archived: [for (final c in challenges) if (c.isArchived) c],
      customTemplates: templates,
    );
  }

  ChallengeStore _loadV1() {
    final raw = _prefs.getString(_keyV1);
    if (raw == null) return const ChallengeStore();
    return ChallengeStore(active: [
      for (final c in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
        ?_challengeFromJson(c, const {}),
    ]);
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
  }) async {
    final store = await _load();
    for (final c in store.active) {
      if (c.template.id == template.id) return c;
    }
    final now = _clock();
    final taken = {for (final c in [...store.active, ...store.archived]) c.id};
    final base = '${template.id}-${now.microsecondsSinceEpoch}';
    var id = base;
    for (var n = 2; taken.contains(id); n++) {
      id = '$base-$n';
    }
    final c = ActiveChallenge(
      id: id,
      template: template,
      startedOn: dayOf(now),
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
    await _prefs.setString(
      _keyV2,
      jsonEncode({
        'version': 2,
        'templates': [for (final t in next.customTemplates) _templateToJson(t)],
        'challenges': [
          for (final c in [...next.active, ...next.archived]) _challengeToJson(c),
        ],
      }),
    );
    await _prefs.remove(_keyV1);
    _changes.add(next);
  }

  // ---------- JSON ----------

  static Map<String, dynamic> _templateToJson(ChallengeTemplate t) => {
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'emoji': t.emoji,
        if (t.steps.isNotEmpty) 'steps': t.steps,
        if (t.targetDuration case final d?) 'targetMinutes': d.inMinutes,
        'kind': switch (t.kind) {
          DailyKind(days: final d) => {'type': 'daily', 'days': d},
          OneTimeKind(window: final w, date: final d) => {
              'type': 'oneTime',
              'hours': w.inHours,
              'date': d?.toIso8601String(),
            },
          WeeklyGoalKind(target: final n, unit: final u, weekdays: final w) => {
              'type': 'weekly',
              'target': n,
              'unit': u.name,
              if (w.isNotEmpty) 'weekdays': [...w]..sort(),
            },
          JournalKind() => {'type': 'journal'},
        },
      };

  static ChallengeTemplate _templateFromJson(Map<String, dynamic> j) {
    final k = j['kind'] as Map<String, dynamic>;
    final ChallengeKind kind = switch (k['type']) {
      'daily' => DailyKind(days: k['days'] as int?),
      'oneTime' => OneTimeKind(
          Duration(hours: k['hours'] as int),
          date: k['date'] == null ? null : DateTime.parse(k['date'] as String),
        ),
      'weekly' => WeeklyGoalKind(
          k['target'] as int,
          unit: WeeklyUnit.values.byName(k['unit'] as String),
          weekdays: (k['weekdays'] as List? ?? const []).cast<int>().toSet(),
        ),
      _ => const JournalKind(),
    };
    return ChallengeTemplate(
      id: j['id'] as String,
      title: j['title'] as String,
      description: j['description'] as String? ?? '',
      emoji: j['emoji'] as String? ?? '⭐',
      kind: kind,
      steps: (j['steps'] as List? ?? const []).cast<String>(),
      targetDuration: switch (j['targetMinutes']) {
        final int m => Duration(minutes: m),
        _ => null,
      },
    );
  }

  static Map<String, dynamic> _challengeToJson(ActiveChallenge c) => {
        'id': c.id,
        'template': c.template.id,
        if (c.template.isCustom) 'customTemplate': _templateToJson(c.template),
        'startedOn': c.startedOn.toIso8601String(),
        'reminder': [c.reminder.hour, c.reminder.minute],
        'status': c.status.name,
        if (c.finishedOn case final f?) 'finishedOn': f.toIso8601String(),
        'rule': c.rule.name,
        if (c.windowStartedAt case final w?) 'windowStartedAt': w.toIso8601String(),
        if (c.sessionStartedAt case final s?) 'sessionStartedAt': s.toIso8601String(),
        if (c.activityLog.isNotEmpty)
          'activityLog': {
            for (final e in c.activityLog.entries) e.key.toIso8601String(): e.value,
          },
        if (c.stepLog.isNotEmpty)
          'stepLog': {
            for (final e in c.stepLog.entries)
              e.key.toIso8601String(): e.value.toList()..sort(),
          },
        'pauses': [
          for (final p in c.pauses)
            [p.from.toIso8601String(), p.until.toIso8601String()],
        ],
        'checkIns': [
          for (final ci in c.checkIns)
            {
              'day': ci.day.toIso8601String(),
              'status': ci.status.name,
              if (ci.minutes != null) 'minutes': ci.minutes,
              if (ci.note != null) 'note': ci.note,
            },
        ],
      };

  static ActiveChallenge? _challengeFromJson(
    Map<String, dynamic> j,
    Map<String, ChallengeTemplate> customTemplates,
  ) {
    final templateId = j['template'] as String;
    final embedded = j['customTemplate'] as Map<String, dynamic>?;
    final template = customTemplates[templateId] ??
        templateById(templateId) ??
        (embedded == null ? null : _templateFromJson(embedded));
    if (template == null) return null;
    final reminder = (j['reminder'] as List).cast<int>();
    final finishedOn = j['finishedOn'] as String?;
    return ActiveChallenge(
      id: j['id'] as String,
      template: template,
      startedOn: DateTime.parse(j['startedOn'] as String),
      reminder: ReminderTime(reminder[0], reminder[1]),
      status: ChallengeStatus.values.byName(j['status'] as String? ?? 'active'),
      finishedOn: finishedOn == null ? null : DateTime.parse(finishedOn),
      rule: ruleFor(template.kind,
          StreakRule.values.byName(j['rule'] as String? ?? 'relaxed')),
      windowStartedAt: switch (j['windowStartedAt']) {
        final String w => DateTime.parse(w),
        _ => null,
      },
      sessionStartedAt: switch (j['sessionStartedAt']) {
        final String s => DateTime.parse(s),
        _ => null,
      },
      activityLog: {
        for (final e
            in (j['activityLog'] as Map<String, dynamic>? ?? const {}).entries)
          DateTime.parse(e.key): e.value as int,
      },
      stepLog: {
        for (final e in (j['stepLog'] as Map<String, dynamic>? ?? const {}).entries)
          DateTime.parse(e.key): (e.value as List).cast<int>().toSet(),
      },
      pauses: [
        for (final p in (j['pauses'] as List? ?? const []).cast<List>())
          PauseRange(
            from: DateTime.parse(p[0] as String),
            until: DateTime.parse(p[1] as String),
          ),
      ],
      checkIns: [
        for (final ci in (j['checkIns'] as List).cast<Map<String, dynamic>>())
          CheckIn(
            day: DateTime.parse(ci['day'] as String),
            status: CheckInStatus.values.byName(ci['status'] as String),
            minutes: ci['minutes'] as int?,
            note: ci['note'] as String?,
          ),
      ],
    );
  }
}
