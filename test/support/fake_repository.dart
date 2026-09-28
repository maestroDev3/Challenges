import 'dart:async';

import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/challenge_repository.dart';

/// In-Memory-Repository für Widget-Tests (kein I/O).
class FakeChallengeRepository implements ChallengeRepository {
  FakeChallengeRepository({
    List<ActiveChallenge>? initial,
    List<ActiveChallenge>? archived,
    List<ChallengeTemplate>? templates,
    this.today,
  })  : _items = [...?initial],
        _archived = [...?archived],
        _templates = [...?templates];

  final DateTime? today;
  final List<ActiveChallenge> _items;
  final List<ActiveChallenge> _archived;
  final List<ChallengeTemplate> _templates;
  final _changes = StreamController<ChallengeStore>.broadcast();

  List<ActiveChallenge> get items => List.unmodifiable(_items);
  List<ActiveChallenge> get archivedItems => List.unmodifiable(_archived);
  List<ChallengeTemplate> get templates => List.unmodifiable(_templates);

  DateTime get _now => today ?? DateTime(2026, 10, 5);

  ChallengeStore get _store => ChallengeStore(
        active: List.of(_items),
        archived: List.of(_archived),
        customTemplates: List.of(_templates),
      );

  void _emit() => _changes.add(_store);

  @override
  Future<List<ActiveChallenge>> active() async => List.of(_items);

  @override
  Future<List<ActiveChallenge>> archived() async => List.of(_archived);

  @override
  Future<List<ChallengeTemplate>> customTemplates() async => List.of(_templates);

  @override
  Future<ActiveChallenge?> byId(String id) async {
    for (final c in [..._items, ..._archived]) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Stream<List<ActiveChallenge>> watch() => watchStore().map((s) => s.active);

  @override
  Stream<ChallengeStore> watchStore() async* {
    yield _store;
    yield* _changes.stream;
  }

  @override
  Future<ActiveChallenge> start(
    ChallengeTemplate template,
    ReminderTime reminder, {
    StreakRule rule = StreakRule.relaxed,
  }) async {
    for (final c in _items) {
      if (c.template.id == template.id) return c;
    }
    final restarts = _archived.where((c) => c.template.id == template.id).length;
    final c = ActiveChallenge(
      id: restarts == 0 ? template.id : '${template.id}-$restarts',
      template: template,
      startedOn: dayOf(_now),
      reminder: reminder,
      rule: rule,
    );
    _items.add(c);
    _emit();
    return c;
  }

  @override
  Future<void> save(ActiveChallenge challenge) async {
    _items.removeWhere((c) => c.id == challenge.id && challenge.isArchived);
    _archived.removeWhere((c) => c.id == challenge.id);
    if (challenge.isArchived) {
      _archived.add(challenge);
    } else {
      final i = _items.indexWhere((c) => c.id == challenge.id);
      if (i >= 0) _items[i] = challenge;
    }
    _emit();
  }

  @override
  Future<ActiveChallenge?> finish(String id) async {
    final i = _items.indexWhere((c) => c.id == id);
    if (i < 0) return null;
    final done = _items.removeAt(i).finish(_now);
    _archived.add(done);
    _emit();
    return done;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((c) => c.id == id);
    _archived.removeWhere((c) => c.id == id);
    _emit();
  }

  @override
  Future<void> saveTemplate(ChallengeTemplate template) async {
    final i = _templates.indexWhere((t) => t.id == template.id);
    if (i >= 0) {
      _templates[i] = template;
    } else {
      _templates.add(template);
    }
    for (var j = 0; j < _items.length; j++) {
      if (_items[j].template.id == template.id) {
        _items[j] = _items[j].copyWith(template: template);
      }
    }
    _emit();
  }

  @override
  Future<void> deleteTemplate(String id) async {
    if (_items.any((c) => c.template.id == id)) {
      throw StateError('Vorlage wird von einer laufenden Challenge genutzt');
    }
    _templates.removeWhere((t) => t.id == id);
    _emit();
  }

  @override
  Future<void> refresh() async => _emit();
}
