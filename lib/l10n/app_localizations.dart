import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In uk, this message translates to:
  /// **'Bady'**
  String get appTitle;

  /// No description provided for @navToday.
  ///
  /// In uk, this message translates to:
  /// **'Сьогодні'**
  String get navToday;

  /// No description provided for @navMedications.
  ///
  /// In uk, this message translates to:
  /// **'Препарати'**
  String get navMedications;

  /// No description provided for @navSettings.
  ///
  /// In uk, this message translates to:
  /// **'Налаштування'**
  String get navSettings;

  /// No description provided for @todayEmpty.
  ///
  /// In uk, this message translates to:
  /// **'На сьогодні прийомів немає'**
  String get todayEmpty;

  /// No description provided for @todayHint.
  ///
  /// In uk, this message translates to:
  /// **'Додайте препарат і розклад, щоб отримувати нагадування.'**
  String get todayHint;

  /// No description provided for @tomorrow.
  ///
  /// In uk, this message translates to:
  /// **'Завтра'**
  String get tomorrow;

  /// No description provided for @timePassed.
  ///
  /// In uk, this message translates to:
  /// **'Час минув'**
  String get timePassed;

  /// No description provided for @medicationsEmpty.
  ///
  /// In uk, this message translates to:
  /// **'Препаратів ще немає'**
  String get medicationsEmpty;

  /// No description provided for @addMedication.
  ///
  /// In uk, this message translates to:
  /// **'Додати препарат'**
  String get addMedication;

  /// No description provided for @editMedication.
  ///
  /// In uk, this message translates to:
  /// **'Редагувати препарат'**
  String get editMedication;

  /// No description provided for @fieldName.
  ///
  /// In uk, this message translates to:
  /// **'Назва'**
  String get fieldName;

  /// No description provided for @fieldNameRequired.
  ///
  /// In uk, this message translates to:
  /// **'Введіть назву'**
  String get fieldNameRequired;

  /// No description provided for @fieldKind.
  ///
  /// In uk, this message translates to:
  /// **'Тип'**
  String get fieldKind;

  /// No description provided for @kindMedicine.
  ///
  /// In uk, this message translates to:
  /// **'Ліки'**
  String get kindMedicine;

  /// No description provided for @kindSupplement.
  ///
  /// In uk, this message translates to:
  /// **'БАД'**
  String get kindSupplement;

  /// No description provided for @fieldForm.
  ///
  /// In uk, this message translates to:
  /// **'Форма'**
  String get fieldForm;

  /// No description provided for @fieldUnit.
  ///
  /// In uk, this message translates to:
  /// **'Одиниця дози'**
  String get fieldUnit;

  /// No description provided for @fieldUnitHint.
  ///
  /// In uk, this message translates to:
  /// **'табл., капс., мг, мл, крапл.'**
  String get fieldUnitHint;

  /// No description provided for @fieldMeal.
  ///
  /// In uk, this message translates to:
  /// **'Прийом їжі'**
  String get fieldMeal;

  /// No description provided for @fieldNotes.
  ///
  /// In uk, this message translates to:
  /// **'Нотатки'**
  String get fieldNotes;

  /// No description provided for @fieldNotesHint.
  ///
  /// In uk, this message translates to:
  /// **'Від чого, хто призначив, особливості'**
  String get fieldNotesHint;

  /// No description provided for @fieldColor.
  ///
  /// In uk, this message translates to:
  /// **'Колір'**
  String get fieldColor;

  /// No description provided for @save.
  ///
  /// In uk, this message translates to:
  /// **'Зберегти'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In uk, this message translates to:
  /// **'Скасувати'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In uk, this message translates to:
  /// **'Видалити'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In uk, this message translates to:
  /// **'Редагувати'**
  String get edit;

  /// No description provided for @deleteMedicationTitle.
  ///
  /// In uk, this message translates to:
  /// **'Видалити препарат?'**
  String get deleteMedicationTitle;

  /// No description provided for @deleteMedicationBody.
  ///
  /// In uk, this message translates to:
  /// **'Препарат, його розклади та історію буде видалено назавжди.'**
  String get deleteMedicationBody;

  /// No description provided for @deleteScheduleTitle.
  ///
  /// In uk, this message translates to:
  /// **'Видалити розклад?'**
  String get deleteScheduleTitle;

  /// No description provided for @archive.
  ///
  /// In uk, this message translates to:
  /// **'В архів'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In uk, this message translates to:
  /// **'Повернути з архіву'**
  String get unarchive;

  /// No description provided for @archivedSection.
  ///
  /// In uk, this message translates to:
  /// **'Архів'**
  String get archivedSection;

  /// No description provided for @notes.
  ///
  /// In uk, this message translates to:
  /// **'Нотатки'**
  String get notes;

  /// No description provided for @schedules.
  ///
  /// In uk, this message translates to:
  /// **'Розклади'**
  String get schedules;

  /// No description provided for @addSchedule.
  ///
  /// In uk, this message translates to:
  /// **'Додати розклад'**
  String get addSchedule;

  /// No description provided for @noSchedules.
  ///
  /// In uk, this message translates to:
  /// **'Розкладу ще немає. Додайте його, щоб отримувати нагадування.'**
  String get noSchedules;

  /// No description provided for @schedulePaused.
  ///
  /// In uk, this message translates to:
  /// **'Призупинено'**
  String get schedulePaused;

  /// No description provided for @pauseSchedule.
  ///
  /// In uk, this message translates to:
  /// **'Призупинити'**
  String get pauseSchedule;

  /// No description provided for @resumeSchedule.
  ///
  /// In uk, this message translates to:
  /// **'Відновити'**
  String get resumeSchedule;

  /// No description provided for @scheduleTitle.
  ///
  /// In uk, this message translates to:
  /// **'Розклад'**
  String get scheduleTitle;

  /// No description provided for @sectionDays.
  ///
  /// In uk, this message translates to:
  /// **'Дні'**
  String get sectionDays;

  /// No description provided for @patternDaily.
  ///
  /// In uk, this message translates to:
  /// **'Щодня'**
  String get patternDaily;

  /// No description provided for @patternWeekdays.
  ///
  /// In uk, this message translates to:
  /// **'Дні тижня'**
  String get patternWeekdays;

  /// No description provided for @patternEveryN.
  ///
  /// In uk, this message translates to:
  /// **'Кожні N днів'**
  String get patternEveryN;

  /// No description provided for @patternCycle.
  ///
  /// In uk, this message translates to:
  /// **'Цикл'**
  String get patternCycle;

  /// No description provided for @patternAsNeeded.
  ///
  /// In uk, this message translates to:
  /// **'За потреби'**
  String get patternAsNeeded;

  /// No description provided for @everyNLabel.
  ///
  /// In uk, this message translates to:
  /// **'Інтервал, днів'**
  String get everyNLabel;

  /// No description provided for @cycleOn.
  ///
  /// In uk, this message translates to:
  /// **'Днів прийому'**
  String get cycleOn;

  /// No description provided for @cycleOff.
  ///
  /// In uk, this message translates to:
  /// **'Днів перерви'**
  String get cycleOff;

  /// No description provided for @asNeededHint.
  ///
  /// In uk, this message translates to:
  /// **'Нагадувань не буде, прийом відмічається вручну.'**
  String get asNeededHint;

  /// No description provided for @sectionTimes.
  ///
  /// In uk, this message translates to:
  /// **'Час і доза'**
  String get sectionTimes;

  /// No description provided for @addTime.
  ///
  /// In uk, this message translates to:
  /// **'Додати час'**
  String get addTime;

  /// No description provided for @generateTimes.
  ///
  /// In uk, this message translates to:
  /// **'Кожні N годин'**
  String get generateTimes;

  /// No description provided for @everyHours.
  ///
  /// In uk, this message translates to:
  /// **'Інтервал, годин'**
  String get everyHours;

  /// No description provided for @fromTime.
  ///
  /// In uk, this message translates to:
  /// **'З'**
  String get fromTime;

  /// No description provided for @untilTime.
  ///
  /// In uk, this message translates to:
  /// **'До'**
  String get untilTime;

  /// No description provided for @dose.
  ///
  /// In uk, this message translates to:
  /// **'Доза'**
  String get dose;

  /// No description provided for @apply.
  ///
  /// In uk, this message translates to:
  /// **'Застосувати'**
  String get apply;

  /// No description provided for @sectionDuration.
  ///
  /// In uk, this message translates to:
  /// **'Тривалість'**
  String get sectionDuration;

  /// No description provided for @startDate.
  ///
  /// In uk, this message translates to:
  /// **'Початок'**
  String get startDate;

  /// No description provided for @durForever.
  ///
  /// In uk, this message translates to:
  /// **'Безстроково'**
  String get durForever;

  /// No description provided for @durDays.
  ///
  /// In uk, this message translates to:
  /// **'Кількість днів'**
  String get durDays;

  /// No description provided for @durUntil.
  ///
  /// In uk, this message translates to:
  /// **'До дати'**
  String get durUntil;

  /// No description provided for @durDoses.
  ///
  /// In uk, this message translates to:
  /// **'Кількість доз'**
  String get durDoses;

  /// No description provided for @endDate.
  ///
  /// In uk, this message translates to:
  /// **'Дата завершення'**
  String get endDate;

  /// No description provided for @preview.
  ///
  /// In uk, this message translates to:
  /// **'Найближчі 7 днів'**
  String get preview;

  /// No description provided for @previewEmpty.
  ///
  /// In uk, this message translates to:
  /// **'У найближчі 7 днів прийомів немає'**
  String get previewEmpty;

  /// No description provided for @problemNoTimes.
  ///
  /// In uk, this message translates to:
  /// **'Додайте хоча б один час прийому'**
  String get problemNoTimes;

  /// No description provided for @problemDuplicateTimes.
  ///
  /// In uk, this message translates to:
  /// **'Час прийому повторюється'**
  String get problemDuplicateTimes;

  /// No description provided for @problemBadDose.
  ///
  /// In uk, this message translates to:
  /// **'Доза має бути більшою за нуль'**
  String get problemBadDose;

  /// No description provided for @problemNoWeekdays.
  ///
  /// In uk, this message translates to:
  /// **'Виберіть хоча б один день тижня'**
  String get problemNoWeekdays;

  /// No description provided for @problemBadEveryN.
  ///
  /// In uk, this message translates to:
  /// **'Інтервал має бути щонайменше 1 день'**
  String get problemBadEveryN;

  /// No description provided for @problemBadCycle.
  ///
  /// In uk, this message translates to:
  /// **'Перевірте кількість днів циклу'**
  String get problemBadCycle;

  /// No description provided for @problemBadDuration.
  ///
  /// In uk, this message translates to:
  /// **'Перевірте тривалість курсу'**
  String get problemBadDuration;

  /// No description provided for @sumDaily.
  ///
  /// In uk, this message translates to:
  /// **'щодня'**
  String get sumDaily;

  /// No description provided for @sumAsNeeded.
  ///
  /// In uk, this message translates to:
  /// **'за потреби'**
  String get sumAsNeeded;

  /// No description provided for @settingsLanguage.
  ///
  /// In uk, this message translates to:
  /// **'Мова'**
  String get settingsLanguage;

  /// No description provided for @langSystem.
  ///
  /// In uk, this message translates to:
  /// **'Як у системі'**
  String get langSystem;

  /// No description provided for @settingsNotifications.
  ///
  /// In uk, this message translates to:
  /// **'Нагадування'**
  String get settingsNotifications;

  /// No description provided for @grantNotifications.
  ///
  /// In uk, this message translates to:
  /// **'Дозволити сповіщення'**
  String get grantNotifications;

  /// No description provided for @grantExactAlarms.
  ///
  /// In uk, this message translates to:
  /// **'Дозволити точні нагадування'**
  String get grantExactAlarms;

  /// No description provided for @grantExactAlarmsHint.
  ///
  /// In uk, this message translates to:
  /// **'Без цього Android може затримувати нагадування на кілька хвилин.'**
  String get grantExactAlarmsHint;

  /// No description provided for @testNotification.
  ///
  /// In uk, this message translates to:
  /// **'Надіслати тестове нагадування'**
  String get testNotification;

  /// No description provided for @testNotificationBody.
  ///
  /// In uk, this message translates to:
  /// **'Нагадування працюють.'**
  String get testNotificationBody;

  /// No description provided for @scheduledCount.
  ///
  /// In uk, this message translates to:
  /// **'Заплановано нагадувань: {count}'**
  String scheduledCount(int count);

  /// No description provided for @about.
  ///
  /// In uk, this message translates to:
  /// **'Про застосунок'**
  String get about;

  /// No description provided for @disclaimer.
  ///
  /// In uk, this message translates to:
  /// **'Bady допомагає не забувати про прийом, але не замінює консультацію лікаря.'**
  String get disclaimer;

  /// No description provided for @notifTitle.
  ///
  /// In uk, this message translates to:
  /// **'Час прийняти ліки'**
  String get notifTitle;

  /// No description provided for @notifChannelName.
  ///
  /// In uk, this message translates to:
  /// **'Нагадування про прийом'**
  String get notifChannelName;

  /// No description provided for @notifChannelDescription.
  ///
  /// In uk, this message translates to:
  /// **'Сповіщення в запланований час прийому'**
  String get notifChannelDescription;

  /// No description provided for @formName.
  ///
  /// In uk, this message translates to:
  /// **'{form, select, tablet{Таблетка} capsule{Капсула} drops{Краплі} liquid{Рідина} powder{Порошок} injection{Ін\'єкція} spray{Спрей} other{Інше}}'**
  String formName(String form);

  /// No description provided for @mealName.
  ///
  /// In uk, this message translates to:
  /// **'{meal, select, any{Неважливо} before{До їжі} during{Під час їжі} after{Після їжі} emptyStomach{Натщесерце} other{}}'**
  String mealName(String meal);

  /// No description provided for @sumEveryN.
  ///
  /// In uk, this message translates to:
  /// **'{n, plural, one{кожен {n} день} few{кожні {n} дні} many{кожні {n} днів} other{кожні {n} дня}}'**
  String sumEveryN(int n);

  /// No description provided for @sumCycle.
  ///
  /// In uk, this message translates to:
  /// **'{on} дн. прийому, {off} дн. перерви'**
  String sumCycle(int on, int off);

  /// No description provided for @sumUntil.
  ///
  /// In uk, this message translates to:
  /// **'до {date}'**
  String sumUntil(String date);

  /// No description provided for @sumFrom.
  ///
  /// In uk, this message translates to:
  /// **'з {date}'**
  String sumFrom(String date);

  /// No description provided for @sumForDays.
  ///
  /// In uk, this message translates to:
  /// **'{n, plural, one{{n} день} few{{n} дні} many{{n} днів} other{{n} дня}}'**
  String sumForDays(int n);

  /// No description provided for @sumForDoses.
  ///
  /// In uk, this message translates to:
  /// **'{n, plural, one{{n} доза} few{{n} дози} many{{n} доз} other{{n} дози}}'**
  String sumForDoses(int n);

  /// No description provided for @daysLeft.
  ///
  /// In uk, this message translates to:
  /// **'{n, plural, one{залишився {n} день} few{залишилось {n} дні} many{залишилось {n} днів} other{залишилось {n} дня}}'**
  String daysLeft(int n);

  /// No description provided for @removeTime.
  ///
  /// In uk, this message translates to:
  /// **'Прибрати час'**
  String get removeTime;

  /// No description provided for @decrease.
  ///
  /// In uk, this message translates to:
  /// **'Зменшити'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In uk, this message translates to:
  /// **'Збільшити'**
  String get increase;

  /// No description provided for @colorOption.
  ///
  /// In uk, this message translates to:
  /// **'Колір {n}'**
  String colorOption(int n);

  /// No description provided for @selectedLabel.
  ///
  /// In uk, this message translates to:
  /// **'вибрано'**
  String get selectedLabel;

  /// No description provided for @requiredHint.
  ///
  /// In uk, this message translates to:
  /// **'* обов\'язкове поле'**
  String get requiredHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
