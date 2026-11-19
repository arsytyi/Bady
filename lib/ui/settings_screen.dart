import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/settings.dart';
import '../services/sound_picker.dart';
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
    final themeMode = ref.watch(themeModeProvider);
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
          SectionTitle(l.settingsAppearance),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg,
              vertical: Spacing.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(l.themeSystem),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(l.themeLight),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(l.themeDark),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).set(s.first),
              ),
            ),
          ),
          SectionTitle(l.settingsNotifications),
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: Text(l.settingsSound),
            subtitle: Text(soundName(reminders.sound, reminders.soundTitle, l)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => const _SoundSheet(),
            ).whenComplete(SoundPicker.stop),
          ),
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
            title: const Text('Bady 0.5.0'),
            subtitle: Text(l.disclaimer),
          ),
        ],
      ),
    );
  }
}

/// Display name of a sound setting.
String soundName(String? sound, String? title, AppLocalizations l) {
  if (sound == null) return l.soundDefault;
  if (sound.startsWith('raw:')) return builtInSoundName(sound.substring(4), l);
  return title ?? l.soundCustom;
}

String builtInSoundName(String name, AppLocalizations l) => switch (name) {
  'bady_chime' => l.soundChime,
  'bady_bell' => l.soundBell,
  'bady_soft' => l.soundSoft,
  'bady_pulse' => l.soundPulse,
  _ => name,
};

/// Pick the reminder sound: phone default, a Bady sound, or any sound on
/// the phone (the Android picker also lets the user add their own file).
class _SoundSheet extends ConsumerWidget {
  const _SoundSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(reminderSettingsProvider);
    final notifier = ref.read(reminderSettingsProvider.notifier);
    final current = settings.sound;
    final isCustom = current != null && !current.startsWith('raw:');

    Future<void> choose(String? sound) async {
      await notifier.setSound(sound);
      await SoundPicker.play(sound);
    }

    Widget preview(String? sound) => IconButton(
      tooltip: l.soundPreview,
      icon: const Icon(Icons.play_circle_outline),
      onPressed: () => SoundPicker.play(sound),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Spacing.lg),
        child: RadioGroup<String>(
          groupValue: current ?? '',
          onChanged: (v) => choose(v == null || v.isEmpty ? null : v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: Text(
                  l.settingsSound,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              RadioListTile(
                value: '',
                title: Text(l.soundDefault),
                secondary: preview(null),
              ),
              SectionTitle(l.soundBuiltIn),
              for (final name in Prefs.builtInSounds)
                RadioListTile(
                  value: 'raw:$name',
                  title: Text(builtInSoundName(name, l)),
                  secondary: preview('raw:$name'),
                ),
              if (isCustom)
                RadioListTile(
                  value: current,
                  title: Text(settings.soundTitle ?? l.soundCustom),
                  secondary: preview(current),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: Text(l.soundPickPhone),
                subtitle: Text(l.soundPickPhoneHint),
                onTap: () async {
                  final picked = await SoundPicker.pick(current);
                  if (picked != null) {
                    await notifier.setSound(picked.sound, title: picked.title);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
