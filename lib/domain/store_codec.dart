import 'dart:convert';

import 'active_challenge.dart';
import 'catalog.dart';
import 'challenge.dart';
import 'challenge_repository.dart';

// JSON-Format des gespeicherten Stands – geteilt von lokalem Speicher und
// Backup-Datei, damit beide immer dasselbe verstehen.

/// Version der Backup-Datei; neuere Dateien lehnt [decodeBackup] ab.
const backupVersion = 1;

const _backupFormat = 'ritual-backup';

/// Inhalt einer Backup-Datei.
class Backup {
  const Backup({required this.store, required this.exportedAt});

  final ChallengeStore store;
  final DateTime exportedAt;
}

/// Speicherformat v2: `{version, templates, challenges}`.
String encodeStore(ChallengeStore store) => jsonEncode({
      'version': 2,
      ..._storeToJson(store),
    });

/// Liest das Speicherformat v2.
ChallengeStore decodeStore(String text) =>
    _storeFromJson(jsonDecode(text) as Map<String, dynamic>);

/// Liest das alte Format v1 (nur aktive Katalog-Challenges).
ChallengeStore decodeLegacyStore(String text) => ChallengeStore(active: [
      for (final c in (jsonDecode(text) as List).cast<Map<String, dynamic>>())
        ?_challengeFromJson(c, const {}),
    ]);

/// Backup-Datei mit Kennung, Version und Exportzeitpunkt.
String encodeBackup(ChallengeStore store, {required DateTime exportedAt}) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': _backupFormat,
      'version': backupVersion,
      'exportedAt': exportedAt.toIso8601String(),
      ..._storeToJson(store),
    });

/// Liest eine Backup-Datei; alles Unerwartete wird zur [FormatException],
/// damit die App nie einen halben Stand übernimmt.
Backup decodeBackup(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw const FormatException('Keine gültige Backup-Datei');
  }
  if (json is! Map<String, dynamic> || json['format'] != _backupFormat) {
    throw const FormatException('Keine Ritual-Backup-Datei');
  }
  final version = json['version'];
  if (version is! int || version > backupVersion) {
    throw const FormatException('Backup stammt aus einer neueren App-Version');
  }
  try {
    return Backup(
      store: _storeFromJson(json, strict: true),
      exportedAt: DateTime.parse(json['exportedAt'] as String),
    );
  } on FormatException {
    rethrow;
  } on Object catch (_) {
    // Typ- und Wertfehler aus beschädigten Dateien.
    throw const FormatException('Backup-Datei ist beschädigt');
  }
}

Map<String, dynamic> _storeToJson(ChallengeStore store) => {
      'templates': [for (final t in store.customTemplates) _templateToJson(t)],
      'challenges': [
        for (final c in [...store.active, ...store.archived]) _challengeToJson(c),
      ],
    };

ChallengeStore _storeFromJson(Map<String, dynamic> json, {bool strict = false}) {
  final templates = [
    for (final t in (json['templates'] as List).cast<Map<String, dynamic>>())
      _templateFromJson(t),
  ];
  final byId = {for (final t in templates) t.id: t};
  final challenges = <ActiveChallenge>[];
  for (final c in (json['challenges'] as List).cast<Map<String, dynamic>>()) {
    final challenge = _challengeFromJson(c, byId);
    if (challenge != null) {
      challenges.add(challenge);
    } else if (strict) {
      throw FormatException('Unbekannte Vorlage in Challenge ${c['id']}');
    }
  }
  return ChallengeStore(
    active: [for (final c in challenges) if (!c.isArchived) c],
    archived: [for (final c in challenges) if (c.isArchived) c],
    customTemplates: templates,
  );
}

Map<String, dynamic> _templateToJson(ChallengeTemplate t) => {
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

ChallengeTemplate _templateFromJson(Map<String, dynamic> j) {
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

Map<String, dynamic> _challengeToJson(ActiveChallenge c) => {
      'id': c.id,
      'template': c.template.id,
      if (c.template.isCustom) 'customTemplate': _templateToJson(c.template),
      'startedOn': c.startedOn.toIso8601String(),
      'reminder': [c.reminder.hour, c.reminder.minute],
      'status': c.status.name,
      if (c.finishedOn case final f?) 'finishedOn': f.toIso8601String(),
      'rule': c.rule.name,
      if (c.planWhen case final w?) 'planWhen': w,
      if (c.planWhere case final w?) 'planWhere': w,
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

ActiveChallenge? _challengeFromJson(
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
    planWhen: j['planWhen'] as String?,
    planWhere: j['planWhere'] as String?,
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
