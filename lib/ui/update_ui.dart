import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/files.dart';
import '../services/settings.dart';
import '../services/update_check.dart';

/// Offers to download [update].
Future<void> showUpdateDialog(BuildContext context, UpdateInfo update) async {
  final l = AppLocalizations.of(context);
  final download = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.system_update),
      title: Text(l.updateAvailable(update.version)),
      content: Text(l.updateHint),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(l.later),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l.updateDownload),
        ),
      ],
    ),
  );
  if (download ?? false) {
    await DeviceFiles.openUrl(update.apkUrl ?? update.pageUrl);
  }
}

/// Checks at most once a day when automatic checks are on.
Future<void> autoCheckForUpdate(
  BuildContext context,
  SharedPreferences prefs, {
  DateTime? now,
}) async {
  if (!DeviceFiles.supported) return;
  if (!(prefs.getBool(Prefs.autoUpdateCheck) ?? true)) return;
  final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final last = prefs.getInt(Prefs.lastUpdateCheck) ?? 0;
  if (t - last < const Duration(days: 1).inMilliseconds) return;
  final result = await UpdateCheck.check();
  if (!result.checked) return;
  await prefs.setInt(Prefs.lastUpdateCheck, t);
  if (result.update case final u? when context.mounted) {
    await showUpdateDialog(context, u);
  }
}
