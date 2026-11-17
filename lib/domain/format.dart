import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'schedule_rule.dart';

/// 1 → "1", 0.5 → "0.5", 1.25 → "1.25".
String formatDose(double dose) {
  if (dose == dose.roundToDouble()) return dose.toInt().toString();
  return dose
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String formatDoseWithUnit(double dose, String unit) => unit.trim().isEmpty
    ? formatDose(dose)
    : '${formatDose(dose)} ${unit.trim()}';

String formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String formatDate(DateTime d, String locale) =>
    DateFormat.yMMMd(locale).format(d);

/// Short weekday names in calendar order Monday…Sunday.
List<String> weekdayNames(String locale) {
  final monday = DateTime(2024, 1, 1); // a Monday
  return [
    for (var i = 0; i < 7; i++)
      DateFormat.E(locale).format(monday.add(Duration(days: i))),
  ];
}

/// One-line human description of a schedule, e.g.
/// "щодня · 08:00 (1), 20:00 (2) · 7 днів".
String describeSchedule(
  ScheduleRule rule,
  AppLocalizations l,
  String locale,
  String unit,
) {
  final parts = <String>[];
  switch (rule.dayPattern) {
    case DayPattern.daily:
      parts.add(l.sumDaily);
    case DayPattern.weekdays:
      final names = weekdayNames(locale);
      final days = rule.weekdays.toList()..sort();
      parts.add(days.map((d) => names[d - 1]).join(', '));
    case DayPattern.everyNDays:
      parts.add(
        rule.everyNDays == 1 ? l.sumDaily : l.sumEveryN(rule.everyNDays),
      );
    case DayPattern.cycle:
      parts.add(l.sumCycle(rule.cycleOnDays, rule.cycleOffDays));
    case DayPattern.asNeeded:
      parts.add(l.sumAsNeeded);
  }
  if (rule.dayPattern != DayPattern.asNeeded && rule.times.isNotEmpty) {
    parts.add(
      rule.times
          .map(
            (t) =>
                '${formatTime(t.hour, t.minute)} (${formatDoseWithUnit(t.dose, unit)})',
          )
          .join(', '),
    );
  }
  switch (rule.durationType) {
    case DurationType.forever:
      break;
    case DurationType.days:
      parts.add(l.sumForDays(rule.durationValue ?? 0));
    case DurationType.untilDate:
      if (rule.endDate != null) {
        parts.add(l.sumUntil(formatDate(rule.endDate!, locale)));
      }
    case DurationType.doseCount:
      parts.add(l.sumForDoses(rule.durationValue ?? 0));
  }
  final today = dateOnly(DateTime.now());
  if (rule.startDate.isAfter(today)) {
    parts.add(l.sumFrom(formatDate(rule.startDate, locale)));
  }
  return parts.join(' · ');
}

String problemText(ScheduleProblem p, AppLocalizations l) => switch (p) {
  ScheduleProblem.noTimes => l.problemNoTimes,
  ScheduleProblem.duplicateTimes => l.problemDuplicateTimes,
  ScheduleProblem.badDose => l.problemBadDose,
  ScheduleProblem.noWeekdays => l.problemNoWeekdays,
  ScheduleProblem.badEveryN => l.problemBadEveryN,
  ScheduleProblem.badCycle => l.problemBadCycle,
  ScheduleProblem.badDuration => l.problemBadDuration,
};
