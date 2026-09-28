import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/active_challenge.dart';
import '../domain/catalog.dart';
import '../domain/challenge.dart';
import '../domain/challenge_repository.dart';

class LocalChallengeRepository implements ChallengeRepository {
  LocalChallengeRepository(this._prefs, {Clock? clock})
      : _clock = clock ?? DateTime.now;

  static const _key = 'active_challenges_v1';

  final SharedPreferences _prefs;
  final Clock _clock;
  final _changes = StreamController<List<ActiveChallenge>>.broadcast();

  @override
  Future<List<ActiveChallenge>> active() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    return [
      for (final e in jsonDecode(raw) as List)
        if (_fromJson(e as Map<String, dynamic>) case final c?) c,
    ];
  }

  @override
  Future<ActiveChallenge?> byId(String id) async {
    for (final c in await active()) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Stream<List<ActiveChallenge>> watch() async* {
    yield await active();
    yield* _changes.stream;
  }

  @override
  Future<ActiveChallenge> start(
      ChallengeTemplate template, ReminderTime reminder) async {
    final all = await active();
    for (final c in all) {
      if (c.template.id == template.id) return c;
    }
    final now = _clock();
    final c = ActiveChallenge(
      id: '${template.id}-${now.microsecondsSinceEpoch}',
      template: template,
      startedOn: dayOf(now),
      reminder: reminder,
    );
    await _write([...all, c]);
    return c;
  }

  @override
  Future<void> save(ActiveChallenge challenge) async {
    final all = await active();
    await _write([
      for (final c in all) c.id == challenge.id ? challenge : c,
    ]);
  }

  @override
  Future<void> stop(String id) async {
    final all = await active();
    await _write([
      for (final c in all)
        if (c.id != id) c,
    ]);
  }

  Future<void> _write(List<ActiveChallenge> all) async {
    await _prefs.setString(_key, jsonEncode([for (final c in all) _toJson(c)]));
    _changes.add(all);
  }

  static Map<String, dynamic> _toJson(ActiveChallenge c) => {
        'id': c.id,
        'template': c.template.id,
        'startedOn': c.startedOn.toIso8601String(),
        'reminder': [c.reminder.hour, c.reminder.minute],
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

  static ActiveChallenge? _fromJson(Map<String, dynamic> j) {
    final template = templateById(j['template'] as String);
    if (template == null) return null;
    final reminder = (j['reminder'] as List).cast<int>();
    return ActiveChallenge(
      id: j['id'] as String,
      template: template,
      startedOn: DateTime.parse(j['startedOn'] as String),
      reminder: ReminderTime(reminder[0], reminder[1]),
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
