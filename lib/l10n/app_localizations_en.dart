// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bady';

  @override
  String get navToday => 'Today';

  @override
  String get navMedications => 'Medications';

  @override
  String get navSettings => 'Settings';

  @override
  String get todayEmpty => 'No doses planned for today';

  @override
  String get todayHint => 'Add a medication and a schedule to get reminders.';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get timePassed => 'Past';

  @override
  String get medicationsEmpty => 'No medications yet';

  @override
  String get addMedication => 'Add medication';

  @override
  String get editMedication => 'Edit medication';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldNameRequired => 'Enter a name';

  @override
  String get fieldKind => 'Type';

  @override
  String get kindMedicine => 'Medicine';

  @override
  String get kindSupplement => 'Supplement';

  @override
  String get fieldForm => 'Form';

  @override
  String get fieldUnit => 'Dose unit';

  @override
  String get fieldUnitHint => 'tablet, capsule, mg, ml, drops';

  @override
  String get fieldMeal => 'Food';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get fieldNotesHint =>
      'What it\'s for, who prescribed it, anything to remember';

  @override
  String get fieldColor => 'Color';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get deleteMedicationTitle => 'Delete medication?';

  @override
  String get deleteMedicationBody =>
      'The medication, its schedules and history will be deleted permanently.';

  @override
  String get deleteScheduleTitle => 'Delete schedule?';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Restore';

  @override
  String get archivedSection => 'Archived';

  @override
  String get notes => 'Notes';

  @override
  String get schedules => 'Schedules';

  @override
  String get addSchedule => 'Add schedule';

  @override
  String get noSchedules => 'No schedule yet. Add one to get reminders.';

  @override
  String get schedulePaused => 'Paused';

  @override
  String get pauseSchedule => 'Pause';

  @override
  String get resumeSchedule => 'Resume';

  @override
  String get scheduleTitle => 'Schedule';

  @override
  String get sectionDays => 'Days';

  @override
  String get patternDaily => 'Every day';

  @override
  String get patternWeekdays => 'Weekdays';

  @override
  String get patternEveryN => 'Every N days';

  @override
  String get patternCycle => 'Cycle';

  @override
  String get patternAsNeeded => 'As needed';

  @override
  String get everyNLabel => 'Interval, days';

  @override
  String get cycleOn => 'Days on';

  @override
  String get cycleOff => 'Days off';

  @override
  String get asNeededHint => 'No reminders; log doses manually.';

  @override
  String get sectionTimes => 'Time and dose';

  @override
  String get addTime => 'Add time';

  @override
  String get generateTimes => 'Every N hours';

  @override
  String get everyHours => 'Interval, hours';

  @override
  String get fromTime => 'From';

  @override
  String get untilTime => 'Until';

  @override
  String get dose => 'Dose';

  @override
  String get apply => 'Apply';

  @override
  String get sectionDuration => 'Duration';

  @override
  String get startDate => 'Start';

  @override
  String get durForever => 'No end';

  @override
  String get durDays => 'Number of days';

  @override
  String get durUntil => 'Until date';

  @override
  String get durDoses => 'Number of doses';

  @override
  String get endDate => 'End date';

  @override
  String get preview => 'Next 7 days';

  @override
  String get previewEmpty => 'No doses in the next 7 days';

  @override
  String get problemNoTimes => 'Add at least one time';

  @override
  String get problemDuplicateTimes => 'A time is listed twice';

  @override
  String get problemBadDose => 'Dose must be greater than zero';

  @override
  String get problemNoWeekdays => 'Pick at least one weekday';

  @override
  String get problemBadEveryN => 'Interval must be at least 1 day';

  @override
  String get problemBadCycle => 'Check the cycle days';

  @override
  String get problemBadDuration => 'Check the duration';

  @override
  String get sumDaily => 'every day';

  @override
  String get sumAsNeeded => 'as needed';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get langSystem => 'System default';

  @override
  String get settingsNotifications => 'Reminders';

  @override
  String get grantNotifications => 'Allow notifications';

  @override
  String get grantExactAlarms => 'Allow exact reminders';

  @override
  String get grantExactAlarmsHint =>
      'Without this Android may delay reminders by several minutes.';

  @override
  String get testNotification => 'Send a test reminder';

  @override
  String get testNotificationBody => 'Reminders are working.';

  @override
  String scheduledCount(int count) {
    return 'Reminders scheduled: $count';
  }

  @override
  String get about => 'About';

  @override
  String get disclaimer =>
      'Bady helps you remember your doses but does not replace advice from a doctor.';

  @override
  String get notifTitle => 'Time for your medication';

  @override
  String get notifChannelName => 'Dose reminders';

  @override
  String get notifChannelDescription => 'Alerts at planned dose times';

  @override
  String formName(String form) {
    String _temp0 = intl.Intl.selectLogic(form, {
      'tablet': 'Tablet',
      'capsule': 'Capsule',
      'drops': 'Drops',
      'liquid': 'Liquid',
      'powder': 'Powder',
      'injection': 'Injection',
      'spray': 'Spray',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String mealName(String meal) {
    String _temp0 = intl.Intl.selectLogic(meal, {
      'any': 'Doesn\'t matter',
      'before': 'Before food',
      'during': 'With food',
      'after': 'After food',
      'emptyStomach': 'On an empty stomach',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String sumEveryN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'every $n days',
      one: 'every day',
    );
    return '$_temp0';
  }

  @override
  String sumCycle(int on, int off) {
    return '$on days on, $off days off';
  }

  @override
  String sumUntil(String date) {
    return 'until $date';
  }

  @override
  String sumFrom(String date) {
    return 'from $date';
  }

  @override
  String sumForDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '$n day',
    );
    return '$_temp0';
  }

  @override
  String sumForDoses(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n doses',
      one: '$n dose',
    );
    return '$_temp0';
  }

  @override
  String daysLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days left',
      one: '$n day left',
    );
    return '$_temp0';
  }

  @override
  String get removeTime => 'Remove time';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String colorOption(int n) {
    return 'Color $n';
  }

  @override
  String get selectedLabel => 'selected';

  @override
  String get requiredHint => '* required';
}
