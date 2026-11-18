import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/settings.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _pending;
  bool? _exact;

  Future<void> _refresh() async {
    final service = ref.read(notificationServiceProvider);
    final pending = await service.pendingCount();
    final exact = await service.canScheduleExact();
    if (mounted) {
      setState(() {
        _pending = pending;
        _exact = exact;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final reminders = ref.watch(reminderSettingsProvider);
    final service = ref.read(notificationServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        children: [
          SectionTitle(l.settingsLanguage),
          RadioGroup<String>(
            groupValue: locale?.languageCode ?? '',
            onChanged: (code) => ref
                .read(localeProvider.notifier)
                .set(code == null || code.isEmpty ? null : Locale(code)),
            child: Column(
              children: [
                RadioListTile(value: '', title: Text(l.langSystem)),
                const RadioListTile(value: 'uk', title: Text('Українська')),
                const RadioListTile(value: 'en', title: Text('English')),
              ],
            ),
          ),
          SectionTitle(l.settingsNotifications),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l.grantNotifications),
            onTap: () async {
              await service.requestPermissions();
              await _refresh();
            },
          ),
          if (_exact == false)
            ListTile(
              leading: const Icon(Icons.alarm_on_outlined),
              title: Text(l.grantExactAlarms),
              subtitle: Text(l.grantExactAlarmsHint),
              onTap: () async {
                await service.requestExactAlarms();
                await ref.read(reminderSyncProvider).resync();
                await _refresh();
              },
            ),
          ListTile(
            leading: const Icon(Icons.snooze),
            title: Text(l.snoozeDuration),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final m in Prefs.snoozeChoices)
                    ButtonSegment(value: m, label: Text(l.minutesShort(m))),
                ],
                selected: {reminders.snoozeMinutes},
                onSelectionChanged: (s) => ref
                    .read(reminderSettingsProvider.notifier)
                    .setSnooze(s.first),
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.repeat),
            title: Text(l.repeatReminders),
            subtitle: Text(l.repeatRemindersHint),
            value: reminders.repeat,
            onChanged: (v) =>
                ref.read(reminderSettingsProvider.notifier).setRepeat(v),
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: Text(l.testNotification),
            subtitle: _pending == null
                ? null
                : Text(l.scheduledCount(_pending!)),
            onTap: () => service.showTest(l),
          ),
          SectionTitle(l.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Bady 0.1.0'),
            subtitle: Text(l.disclaimer),
          ),
        ],
      ),
    );
  }
}
