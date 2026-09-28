import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/active_challenge.dart';
import '../domain/reminders.dart';

typedef NotificationResponseHandler = void Function(NotificationResponse);

/// Android-Implementierung mit flutter_local_notifications.
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _permissionAsked = false;

  static const _channel = AndroidNotificationDetails(
    'challenge_reminders',
    'Challenge-Erinnerungen',
    channelDescription: 'Tägliche Erinnerung an deine Challenges',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  static Future<LocalNotificationScheduler> create({
    required NotificationResponseHandler onResponse,
    required NotificationResponseHandler onBackgroundResponse,
  }) async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    }
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
    return LocalNotificationScheduler._(plugin);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> _ensurePermissions() async {
    final android = _android;
    if (android == null) return false;
    if (!_permissionAsked) {
      _permissionAsked = true;
      await android.requestNotificationsPermission();
      if (await android.canScheduleExactNotifications() != true) {
        await android.requestExactAlarmsPermission();
      }
    }
    return await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> schedule(ActiveChallenge challenge) async {
    final id = notificationIdFor(challenge.id);
    final when = firstReminder(challenge, DateTime.now());
    if (when == null) {
      await _plugin.cancel(id: id);
      return;
    }
    final exact = await _ensurePermissions();
    final t = challenge.template;
    final (body, actions) = switch (reminderActionsFor(t.kind)) {
      ReminderActions.journalInput => (
          'Welche Ausrede hattest du heute?',
          const [
            AndroidNotificationAction(
              actionDone,
              'Aufschreiben',
              inputs: [AndroidNotificationActionInput(label: 'Deine Ausrede')],
            ),
          ],
        ),
      ReminderActions.none => (
          'Trag deine Minuten in der App ein.',
          const <AndroidNotificationAction>[],
        ),
      ReminderActions.doneMissed => (
          'Hast du es heute geschafft?',
          const [
            AndroidNotificationAction(actionDone, '✓ Erledigt'),
            AndroidNotificationAction(actionMissed, '✗ Nicht erledigt'),
          ],
        ),
    };

    await _plugin.cancel(id: id);
    await _plugin.zonedSchedule(
      id: id,
      title: '${t.emoji} ${t.title}',
      body: body,
      payload: challenge.id,
      scheduledDate: tz.TZDateTime(tz.local, when.year, when.month, when.day,
          when.hour, when.minute),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.channelId,
          _channel.channelName,
          channelDescription: _channel.channelDescription,
          importance: _channel.importance,
          priority: _channel.priority,
          category: _channel.category,
          actions: actions,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          reminderRepeats(challenge) ? DateTimeComponents.time : null,
    );
  }

  @override
  Future<void> cancel(ActiveChallenge challenge) =>
      _plugin.cancel(id: notificationIdFor(challenge.id));
}
