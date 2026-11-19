import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/dose_plan.dart';
import '../domain/enums.dart';
import '../domain/format.dart';
import '../domain/look.dart';
import '../domain/notification_payload.dart';
import '../domain/schedule_rule.dart';
import '../l10n/app_localizations.dart';
import '../ui/pill_icon.dart';

bool _tzReady = false;

/// Loads time-zone data and the device zone. Safe to call from any isolate.
Future<void> initTimeZones() async {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (e) {
    debugPrint('Timezone lookup failed, using UTC: $e');
  }
  _tzReady = true;
}

/// Schedules local reminders with Android exact alarms. Each reminder has
/// Taken / Snooze / Skip buttons that work without opening the app.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const horizon = Duration(days: 14);

  /// Android refuses more than 500 alarms per app, so the furthest
  /// reminders wait for the next resync when a plan is very busy.
  static const maxPending = 450;
  static const _defaultChannelId = 'dose_reminders';
  static const _stockChannelId = 'stock';

  /// Restock reminders use negative ids, one per day, so they never clash
  /// with dose reminders.
  static int stockNotificationId(DateTime at) =>
      -1 - daysBetween(DateTime(2020), dateOnly(at));

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// Sound key from settings (see `Prefs.sound`). Android fixes a channel's
  /// sound when it is created, so every sound gets its own channel.
  String? sound;

  static String channelIdFor(String? sound) {
    if (sound == null) return _defaultChannelId;
    // FNV-1a, stable across runs and isolates.
    var h = 0x811c9dc5;
    for (final c in sound.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return 'dose_${h.toRadixString(16)}';
  }

  static AndroidNotificationSound? _soundFor(String? key) {
    if (key == null) return null;
    if (key.startsWith('raw:')) {
      return RawResourceAndroidNotificationSound(key.substring(4));
    }
    return UriAndroidNotificationSound(key);
  }

  static bool get supported => !kIsWeb && Platform.isAndroid;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Call once in the main isolate. [onResponse] handles taps and actions
  /// while the app is running; [onBackgroundResponse] must be a top-level
  /// function annotated with `@pragma('vm:entry-point')`.
  Future<void> init({
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    if (_ready || !supported) return;
    await initTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_dose'),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
    _ready = true;
  }

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload() async {
    if (!supported) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final response = details!.notificationResponse;
    // A button press is handled in the background; only a tap opens a dose.
    if (response?.actionId != null) return null;
    return response?.payload;
  }

  Future<bool> requestPermissions() async {
    if (!supported) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> canScheduleExact() async {
    if (!supported) return false;
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarms() async {
    if (!supported) return;
    await _android?.requestExactAlarmsPermission();
  }

  NotificationDetails _details(
    AppLocalizations l, {
    bool actions = true,
    Uint8List? largeIcon,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      channelIdFor(sound),
      l.notifChannelName,
      channelDescription: l.notifChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      sound: _soundFor(sound),
      category: AndroidNotificationCategory.reminder,
      styleInformation: const DefaultStyleInformation(true, true),
      largeIcon: largeIcon == null ? null : ByteArrayAndroidBitmap(largeIcon),
      actions: actions
          ? [
              AndroidNotificationAction(
                NotificationActions.taken,
                l.actionTaken,
              ),
              AndroidNotificationAction(
                NotificationActions.snooze,
                l.actionSnooze,
              ),
              AndroidNotificationAction(NotificationActions.skip, l.actionSkip),
            ]
          : null,
    ),
  );

  static String body(PlannedNotification n, AppLocalizations l) => n.items
      .map(
        (i) => [
          '${i.name}: ${formatDoseWithUnit(i.dose, i.unit, l)}',
          if (i.meal != MealRelation.any) l.mealName(i.meal.name),
        ].join(' · '),
      )
      .join('\n');

  String _title(PlannedNotification n, AppLocalizations l) {
    final time = formatTime(n.doseTime.hour, n.doseTime.minute);
    return switch (n.kind) {
      NotificationKind.main => '${l.notifTitle} · $time',
      NotificationKind.followUp => '${l.notifTitleRepeat} · $time',
      NotificationKind.snooze => '${l.notifTitleSnoozed} · $time',
    };
  }

  static String payloadFor(PlannedNotification n) => NotificationPayload(
    doseTime: n.doseTime,
    doses: {for (final i in n.items) i.medicationId: i.dose},
  ).encode();

  Future<void> schedule(
    PlannedNotification n,
    AppLocalizations l, {
    AndroidScheduleMode? mode,
  }) async {
    await _plugin.zonedSchedule(
      id: n.id,
      scheduledDate: tz.TZDateTime.from(n.at, tz.local),
      notificationDetails: _details(l, largeIcon: await _iconFor(n)),
      androidScheduleMode:
          mode ??
          (await canScheduleExact()
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle),
      title: _title(n, l),
      body: body(n, l),
      payload: payloadFor(n),
    );
  }

  final _iconCache = <(PillShape, int, int?), Uint8List>{};

  /// Drawing of the first medication in the reminder.
  Future<Uint8List?> _iconFor(PlannedNotification n) async {
    if (n.items.isEmpty) return null;
    final look = n.items.first.look;
    final key = (look.shape, look.color, look.color2);
    try {
      return _iconCache[key] ??= await renderPillPng(
        shape: look.shape,
        color: look.color,
        color2: look.color2,
      );
    } catch (e) {
      debugPrint('Pill icon failed: $e');
      return null;
    }
  }

  /// Replaces all pending reminders. Returns how many were scheduled.
  Future<int> replaceAll(
    List<PlannedNotification> plan,
    AppLocalizations l, {
    Map<DateTime, List<String>> stock = const {},
  }) async {
    if (!supported) return 0;
    await _plugin.cancelAllPendingNotifications();
    await _removeOldChannels();
    final mode = await canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = DateTime.now();
    final upcoming = [
      for (final n in plan)
        if (n.at.isAfter(now)) n,
    ]..sort((a, b) => a.at.compareTo(b.at));
    final stockTimes = [
      for (final at in stock.keys)
        if (at.isAfter(now)) at,
    ]..sort();
    var count = 0;
    for (final n in upcoming.take(maxPending - min(stockTimes.length, 7))) {
      await schedule(n, l, mode: mode);
      count++;
    }
    for (final at in stockTimes) {
      if (count >= maxPending) break;
      final names = stock[at]!;
      await _plugin.zonedSchedule(
        id: stockNotificationId(at),
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _stockChannelId,
            l.notifStockChannelName,
            channelDescription: l.notifStockChannelDescription,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: l.stockBanner,
        body: names.join(', '),
      );
      count++;
    }
    return count;
  }

  /// Deletes reminder channels left over from earlier sound choices.
  Future<void> _removeOldChannels() async {
    try {
      final current = channelIdFor(sound);
      for (final c in await _android?.getNotificationChannels() ?? const []) {
        final isOurs = c.id == _defaultChannelId || c.id.startsWith('dose_');
        if (isOurs && c.id != current) {
          await _android?.deleteNotificationChannel(channelId: c.id);
        }
      }
    } catch (e) {
      debugPrint('Channel cleanup failed: $e');
    }
  }

  /// Removes shown and pending notifications for doses at [doseTime].
  Future<void> cancelForDose(DateTime doseTime) async {
    if (!supported) return;
    for (final id in allNotificationIdsFor(doseTime)) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> showTest(AppLocalizations l) async {
    if (!supported) return;
    await _plugin.show(
      id: 0,
      title: l.notifTitle,
      body: l.testNotificationBody,
      notificationDetails: _details(l, actions: false),
    );
  }

  Future<int> pendingCount() async {
    if (!supported) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
  }
}
