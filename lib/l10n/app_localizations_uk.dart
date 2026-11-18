// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Bady';

  @override
  String get navToday => 'Сьогодні';

  @override
  String get navMedications => 'Препарати';

  @override
  String get navSettings => 'Налаштування';

  @override
  String get todayEmpty => 'На сьогодні прийомів немає';

  @override
  String get todayHint =>
      'Додайте препарат і розклад, щоб отримувати нагадування.';

  @override
  String get tomorrow => 'Завтра';

  @override
  String get timePassed => 'Час минув';

  @override
  String get medicationsEmpty => 'Препаратів ще немає';

  @override
  String get addMedication => 'Додати препарат';

  @override
  String get editMedication => 'Редагувати препарат';

  @override
  String get fieldName => 'Назва';

  @override
  String get fieldNameRequired => 'Введіть назву';

  @override
  String get fieldKind => 'Тип';

  @override
  String get kindMedicine => 'Ліки';

  @override
  String get kindSupplement => 'БАД';

  @override
  String get fieldForm => 'Форма';

  @override
  String get fieldUnit => 'Одиниця дози';

  @override
  String get fieldUnitHint => 'табл., капс., мг, мл, крапл.';

  @override
  String get fieldMeal => 'Прийом їжі';

  @override
  String get fieldNotes => 'Нотатки';

  @override
  String get fieldNotesHint => 'Від чого, хто призначив, особливості';

  @override
  String get fieldColor => 'Колір';

  @override
  String get save => 'Зберегти';

  @override
  String get cancel => 'Скасувати';

  @override
  String get delete => 'Видалити';

  @override
  String get edit => 'Редагувати';

  @override
  String get deleteMedicationTitle => 'Видалити препарат?';

  @override
  String get deleteMedicationBody =>
      'Препарат, його розклади та історію буде видалено назавжди.';

  @override
  String get deleteScheduleTitle => 'Видалити розклад?';

  @override
  String get archive => 'В архів';

  @override
  String get unarchive => 'Повернути з архіву';

  @override
  String get archivedSection => 'Архів';

  @override
  String get notes => 'Нотатки';

  @override
  String get schedules => 'Розклади';

  @override
  String get addSchedule => 'Додати розклад';

  @override
  String get noSchedules =>
      'Розкладу ще немає. Додайте його, щоб отримувати нагадування.';

  @override
  String get schedulePaused => 'Призупинено';

  @override
  String get pauseSchedule => 'Призупинити';

  @override
  String get resumeSchedule => 'Відновити';

  @override
  String get scheduleTitle => 'Розклад';

  @override
  String get sectionDays => 'Дні';

  @override
  String get patternDaily => 'Щодня';

  @override
  String get patternWeekdays => 'Дні тижня';

  @override
  String get patternEveryN => 'Кожні N днів';

  @override
  String get patternCycle => 'Цикл';

  @override
  String get patternAsNeeded => 'За потреби';

  @override
  String get everyNLabel => 'Інтервал, днів';

  @override
  String get cycleOn => 'Днів прийому';

  @override
  String get cycleOff => 'Днів перерви';

  @override
  String get asNeededHint => 'Нагадувань не буде, прийом відмічається вручну.';

  @override
  String get sectionTimes => 'Час і доза';

  @override
  String get addTime => 'Додати час';

  @override
  String get generateTimes => 'Кожні N годин';

  @override
  String get everyHours => 'Інтервал, годин';

  @override
  String get fromTime => 'З';

  @override
  String get untilTime => 'До';

  @override
  String get dose => 'Доза';

  @override
  String get apply => 'Застосувати';

  @override
  String get sectionDuration => 'Тривалість';

  @override
  String get startDate => 'Початок';

  @override
  String get durForever => 'Безстроково';

  @override
  String get durDays => 'Кількість днів';

  @override
  String get durUntil => 'До дати';

  @override
  String get durDoses => 'Кількість доз';

  @override
  String get endDate => 'Дата завершення';

  @override
  String get preview => 'Найближчі 7 днів';

  @override
  String get previewEmpty => 'У найближчі 7 днів прийомів немає';

  @override
  String get problemNoTimes => 'Додайте хоча б один час прийому';

  @override
  String get problemDuplicateTimes => 'Час прийому повторюється';

  @override
  String get problemBadDose => 'Доза має бути більшою за нуль';

  @override
  String get problemNoWeekdays => 'Виберіть хоча б один день тижня';

  @override
  String get problemBadEveryN => 'Інтервал має бути щонайменше 1 день';

  @override
  String get problemBadCycle => 'Перевірте кількість днів циклу';

  @override
  String get problemBadDuration => 'Перевірте тривалість курсу';

  @override
  String get sumDaily => 'щодня';

  @override
  String get sumAsNeeded => 'за потреби';

  @override
  String get settingsLanguage => 'Мова';

  @override
  String get langSystem => 'Як у системі';

  @override
  String get settingsNotifications => 'Нагадування';

  @override
  String get grantNotifications => 'Дозволити сповіщення';

  @override
  String get grantExactAlarms => 'Дозволити точні нагадування';

  @override
  String get grantExactAlarmsHint =>
      'Без цього Android може затримувати нагадування на кілька хвилин.';

  @override
  String get testNotification => 'Надіслати тестове нагадування';

  @override
  String get testNotificationBody => 'Нагадування працюють.';

  @override
  String scheduledCount(int count) {
    return 'Заплановано нагадувань: $count';
  }

  @override
  String get about => 'Про застосунок';

  @override
  String get disclaimer =>
      'Bady допомагає не забувати про прийом, але не замінює консультацію лікаря.';

  @override
  String get notifTitle => 'Час прийняти ліки';

  @override
  String get notifChannelName => 'Нагадування про прийом';

  @override
  String get notifChannelDescription => 'Сповіщення в запланований час прийому';

  @override
  String formName(String form) {
    String _temp0 = intl.Intl.selectLogic(form, {
      'tablet': 'Таблетка',
      'capsule': 'Капсула',
      'drops': 'Краплі',
      'liquid': 'Рідина',
      'powder': 'Порошок',
      'injection': 'Ін\'єкція',
      'spray': 'Спрей',
      'other': 'Інше',
    });
    return '$_temp0';
  }

  @override
  String mealName(String meal) {
    String _temp0 = intl.Intl.selectLogic(meal, {
      'any': 'Неважливо',
      'before': 'До їжі',
      'during': 'Під час їжі',
      'after': 'Після їжі',
      'emptyStomach': 'Натщесерце',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String sumEveryN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'кожні $n дня',
      many: 'кожні $n днів',
      few: 'кожні $n дні',
      one: 'кожен $n день',
    );
    return '$_temp0';
  }

  @override
  String sumCycle(int on, int off) {
    return '$on дн. прийому, $off дн. перерви';
  }

  @override
  String sumUntil(String date) {
    return 'до $date';
  }

  @override
  String sumFrom(String date) {
    return 'з $date';
  }

  @override
  String sumForDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n дня',
      many: '$n днів',
      few: '$n дні',
      one: '$n день',
    );
    return '$_temp0';
  }

  @override
  String sumForDoses(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n дози',
      many: '$n доз',
      few: '$n дози',
      one: '$n доза',
    );
    return '$_temp0';
  }

  @override
  String daysLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'залишилось $n дня',
      many: 'залишилось $n днів',
      few: 'залишилось $n дні',
      one: 'залишився $n день',
    );
    return '$_temp0';
  }

  @override
  String get removeTime => 'Прибрати час';

  @override
  String get decrease => 'Зменшити';

  @override
  String get increase => 'Збільшити';

  @override
  String colorOption(int n) {
    return 'Колір $n';
  }

  @override
  String get selectedLabel => 'вибрано';

  @override
  String get requiredHint => '* обов\'язкове поле';
}
