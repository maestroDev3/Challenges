import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/active_challenge.dart';
import '../domain/reminders.dart';

typedef NotificationResponseHandler = void Function(NotificationResponse);

/// Android-Implementierung mit flutter_local_notifications.
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler._(this._plugin, {required bool askPermissions})
      : _permissionAsked = !askPermissions;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _permissionAsked;

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
    // Im Hintergrund (keine Activity) nicht nach Berechtigungen fragen.
    bool askPermissions = true,
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
    return LocalNotificationScheduler._(plugin, askPermissions: askPermissions);
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
    await cancel(challenge);
    final times = upcomingReminders(challenge, DateTime.now());
    if (times.isEmpty) return;
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

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.channelId,
        _channel.channelName,
        channelDescription: _channel.channelDescription,
        importance: _channel.importance,
        priority: _channel.priority,
        category: _channel.category,
        actions: actions,
      ),
    );
    for (final (i, time) in times.indexed) {
      await _plugin.zonedSchedule(
        id: _slotId(challenge, i),
        title: '${t.emoji} ${t.title}',
        body: body,
        payload: challenge.id,
        scheduledDate: tz.TZDateTime(
            tz.local, time.year, time.month, time.day, time.hour, time.minute),
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static const _sessionChannel = AndroidNotificationDetails(
    'challenge_sessions',
    'Laufende Aktivität',
    channelDescription: 'Stoppuhr, solange du gerade dabei bist',
    importance: Importance.low,
    priority: Priority.low,
  );

  int _sessionId(ActiveChallenge c) => notificationIdFor('session:${c.id}');
  int _targetId(ActiveChallenge c) => notificationIdFor('target:${c.id}');

  @override
  Future<void> showSession(ActiveChallenge challenge) async {
    final start = challenge.sessionStartedAt;
    if (start == null) return;
    final exact = await _ensurePermissions();
    final t = challenge.template;
    await _plugin.show(
      id: _sessionId(challenge),
      title: '${t.emoji} ${t.title}',
      body: switch (t.targetDuration) {
        final d? => 'Läuft – Ziel ${d.inMinutes} min',
        null => 'Läuft',
      },
      payload: challenge.id,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _sessionChannel.channelId,
          _sessionChannel.channelName,
          channelDescription: _sessionChannel.channelDescription,
          importance: _sessionChannel.importance,
          priority: _sessionChannel.priority,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          usesChronometer: true,
          when: start.millisecondsSinceEpoch,
          category: AndroidNotificationCategory.stopwatch,
          actions: const [AndroidNotificationAction(actionStop, '■ Stopp')],
        ),
      ),
    );
    final end = challenge.sessionTargetEnd;
    if (end != null && end.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        id: _targetId(challenge),
        title: '${t.emoji} Zieldauer erreicht',
        body: 'Tippe auf „Stopp“, um die Zeit gutzuschreiben.',
        payload: challenge.id,
        scheduledDate: tz.TZDateTime.from(end, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.channelId,
            _channel.channelName,
            channelDescription: _channel.channelDescription,
            importance: _channel.importance,
            priority: _channel.priority,
            actions: const [AndroidNotificationAction(actionStop, '■ Stopp')],
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  int _slotId(ActiveChallenge c, int slot) =>
      notificationIdFor('${c.id}:r$slot');

  int _weekdayId(ActiveChallenge c, int weekday) =>
      notificationIdFor('${c.id}:wd$weekday');

  @override
  Future<void> clearSession(ActiveChallenge challenge) async {
    await _plugin.cancel(id: _sessionId(challenge));
    await _plugin.cancel(id: _targetId(challenge));
  }

  int _slotId(ActiveChallenge c, int slot) =>
      notificationIdFor('${c.id}:r$slot');

  int _weekdayId(ActiveChallenge c, int weekday) =>
      notificationIdFor('${c.id}:wd$weekday');

  @override
  Future<void> cancel(ActiveChallenge challenge) async {
    // Alte Einzel-/Wochentags-Termine (frühere Versionen) und alle Slots.
    await _plugin.cancel(id: notificationIdFor(challenge.id));
    for (var wd = 1; wd <= 7; wd++) {
      await _plugin.cancel(id: _weekdayId(challenge, wd));
    }
    for (var i = 0; i < maxUpcomingReminders; i++) {
      await _plugin.cancel(id: _slotId(challenge, i));
    }
  }
}
