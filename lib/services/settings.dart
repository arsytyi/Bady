import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// Preference keys and defaults shared by the UI and the background isolate.
abstract final class Prefs {
  static const locale = 'locale';
  static const snoozeMinutes = 'snoozeMinutes';
  static const repeatReminders = 'repeatReminders';

  static const snoozeChoices = [5, 10, 15, 30];
  static const defaultSnooze = 10;
  static const followUpMinutes = [15, 30];

  static int snooze(SharedPreferences p) =>
      p.getInt(snoozeMinutes) ?? defaultSnooze;

  static bool repeat(SharedPreferences p) => p.getBool(repeatReminders) ?? true;

  static Locale? chosenLocale(SharedPreferences p) {
    final code = p.getString(locale);
    return code == null ? null : Locale(code);
  }
}

/// The language actually in use (setting, else system, else Ukrainian).
Locale effectiveLocale(Locale? chosen) {
  if (chosen != null) return chosen;
  for (final l in PlatformDispatcher.instance.locales) {
    if (AppLocalizations.supportedLocales.any(
      (s) => s.languageCode == l.languageCode,
    )) {
      return Locale(l.languageCode);
    }
  }
  return const Locale('uk');
}

AppLocalizations localizationsFor(SharedPreferences p) =>
    lookupAppLocalizations(effectiveLocale(Prefs.chosenLocale(p)));
