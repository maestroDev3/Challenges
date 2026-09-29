import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_challenge_repository.dart';
import 'data/local_notification_scheduler.dart';
import 'domain/challenge_repository.dart';
import 'domain/reminders.dart';
import 'ui/app.dart';

/// Wird von Android aufgerufen, wenn in der Benachrichtigung „Erledigt“ /
/// „Nicht erledigt“ getippt wird, während die App nicht läuft.
@pragma('vm:entry-point')
Future<void> onNotificationActionInBackground(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repository = LocalChallengeRepository(prefs);
  await handleNotificationAction(
    repository,
    actionId: r.actionId,
    payload: r.payload,
    now: DateTime.now(),
    input: r.input,
  );
  // Termine nach dem Abhaken neu planen (z. B. Wochenziel erreicht).
  try {
    final scheduler = await LocalNotificationScheduler.create(
      onResponse: (_) {},
      onBackgroundResponse: onNotificationActionInBackground,
      askPermissions: false,
    );
    await _reschedule(repository, scheduler, r.payload);
  } on Object catch (_) {
    // Beim nächsten App-Start wird ohnehin neu geplant.
  }
}

Future<void> _reschedule(
    ChallengeRepository repository, ReminderScheduler scheduler, String? id) async {
  if (id == null) return;
  final c = await repository.byId(id);
  if (c == null) return;
  if (c.isArchived) {
    await scheduler.cancel(c);
  } else {
    await scheduler.schedule(c);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repository = LocalChallengeRepository(prefs);

  late final LocalNotificationScheduler scheduler;
  scheduler = await LocalNotificationScheduler.create(
    onResponse: (r) async {
      await handleNotificationAction(
        repository,
        actionId: r.actionId,
        payload: r.payload,
        now: DateTime.now(),
        input: r.input,
      );
      await _reschedule(repository, scheduler, r.payload);
    },
    onBackgroundResponse: onNotificationActionInBackground,
  );
  await syncReminders(repository, scheduler, now: DateTime.now());

  runApp(ChallengesApp(repository: repository, scheduler: scheduler));
}
