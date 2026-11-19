import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'domain/notification_payload.dart';
import 'providers.dart';
import 'services/dose_actions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  Future<void> onResponse(NotificationResponse r) async {
    final handled = await container
        .read(doseActionsProvider)
        .handleNotificationResponse(r);
    if (handled) {
      await container.read(reminderSyncProvider).resync();
      return;
    }
    final payload = NotificationPayload.tryDecode(r.payload);
    if (payload != null) {
      container.read(focusRequestProvider.notifier).request(payload.doseTime);
    }
  }

  final notifications = container.read(notificationServiceProvider);
  await notifications.init(
    onResponse: onResponse,
    onBackgroundResponse: onNotificationActionInBackground,
  );
  final launch = NotificationPayload.tryDecode(
    await notifications.launchPayload(),
  );
  if (launch != null) {
    container.read(focusRequestProvider.notifier).request(launch.doseTime);
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const DoseApp()),
  );
}
