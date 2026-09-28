import 'dart:async';

import 'package:challenges/domain/active_challenge.dart';
import 'package:challenges/domain/challenge.dart';
import 'package:challenges/domain/challenge_repository.dart';

/// In-Memory-Repository für Widget-Tests (kein I/O).
class FakeChallengeRepository implements ChallengeRepository {
  FakeChallengeRepository({List<ActiveChallenge>? initial, this.today})
      : _items = [...?initial];

  final DateTime? today;
  final List<ActiveChallenge> _items;
  final _changes = StreamController<List<ActiveChallenge>>.broadcast();

  List<ActiveChallenge> get items => List.unmodifiable(_items);

  @override
  Future<List<ActiveChallenge>> active() async => List.of(_items);

  @override
  Future<ActiveChallenge?> byId(String id) async {
    for (final c in _items) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Stream<List<ActiveChallenge>> watch() async* {
    yield List.of(_items);
    yield* _changes.stream;
  }

  @override
  Future<ActiveChallenge> start(
      ChallengeTemplate template, ReminderTime reminder) async {
    for (final c in _items) {
      if (c.template.id == template.id) return c;
    }
    final c = ActiveChallenge(
      id: template.id,
      template: template,
      startedOn: dayOf(today ?? DateTime(2026, 10, 5)),
      reminder: reminder,
    );
    _items.add(c);
    _changes.add(List.of(_items));
    return c;
  }

  @override
  Future<void> save(ActiveChallenge challenge) async {
    final i = _items.indexWhere((c) => c.id == challenge.id);
    if (i >= 0) _items[i] = challenge;
    _changes.add(List.of(_items));
  }

  @override
  Future<void> refresh() async => _changes.add(List.of(_items));

  @override
  Future<void> stop(String id) async {
    _items.removeWhere((c) => c.id == id);
    _changes.add(List.of(_items));
  }
}
