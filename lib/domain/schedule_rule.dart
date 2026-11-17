/// Pure-Dart description of a flexible intake schedule and the logic that
/// expands it into concrete dose times. No Flutter or database imports, so it
/// is fully unit-testable.
library;

/// How long a schedule runs.
enum DurationType {
  /// No end date.
  forever,

  /// [ScheduleRule.durationValue] days, counting the start day.
  days,

  /// Up to and including [ScheduleRule.endDate].
  untilDate,

  /// Until [ScheduleRule.durationValue] doses have been scheduled.
  doseCount,
}

/// Which days of the calendar a schedule is active on.
enum DayPattern {
  /// Every day.
  daily,

  /// Selected weekdays only ([ScheduleRule.weekdays], 1 = Monday … 7 = Sunday).
  weekdays,

  /// Every [ScheduleRule.everyNDays] days, counting from the start date.
  everyNDays,

  /// [ScheduleRule.cycleOnDays] days on, then [ScheduleRule.cycleOffDays] days
  /// off, repeating from the start date.
  cycle,

  /// No reminders. Doses are logged manually.
  asNeeded,
}

/// One intake within a day: the time and how much to take.
class DoseTime implements Comparable<DoseTime> {
  const DoseTime({required this.hour, required this.minute, this.dose = 1});

  final int hour;
  final int minute;
  final double dose;

  int get minuteOfDay => hour * 60 + minute;

  DoseTime copyWith({int? hour, int? minute, double? dose}) => DoseTime(
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    dose: dose ?? this.dose,
  );

  Map<String, Object> toJson() => {'h': hour, 'm': minute, 'd': dose};

  factory DoseTime.fromJson(Map<String, dynamic> json) => DoseTime(
    hour: json['h'] as int,
    minute: json['m'] as int,
    dose: (json['d'] as num).toDouble(),
  );

  @override
  int compareTo(DoseTime other) => minuteOfDay.compareTo(other.minuteOfDay);

  @override
  bool operator ==(Object other) =>
      other is DoseTime &&
      other.hour == hour &&
      other.minute == minute &&
      other.dose == dose;

  @override
  int get hashCode => Object.hash(hour, minute, dose);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} x$dose';
}

/// A single planned dose produced by [ScheduleRule.occurrences].
class DoseOccurrence {
  const DoseOccurrence(this.at, this.dose);

  final DateTime at;
  final double dose;

  @override
  bool operator ==(Object other) =>
      other is DoseOccurrence && other.at == at && other.dose == dose;

  @override
  int get hashCode => Object.hash(at, dose);

  @override
  String toString() => 'DoseOccurrence($at, $dose)';
}

/// Generates evenly spaced times, e.g. every 8 hours from 06:00 until 22:00.
List<DoseTime> intervalTimes({
  required int everyHours,
  required int fromHour,
  required int fromMinute,
  required int untilHour,
  required int untilMinute,
  double dose = 1,
}) {
  if (everyHours <= 0) throw ArgumentError.value(everyHours, 'everyHours');
  final start = fromHour * 60 + fromMinute;
  final end = untilHour * 60 + untilMinute;
  final result = <DoseTime>[];
  for (var m = start; m <= end && m < 24 * 60; m += everyHours * 60) {
    result.add(DoseTime(hour: m ~/ 60, minute: m % 60, dose: dose));
  }
  return result;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [a] to [b], unaffected by daylight-saving shifts.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

class ScheduleRule {
  ScheduleRule({
    required DateTime startDate,
    this.durationType = DurationType.forever,
    this.durationValue,
    DateTime? endDate,
    this.dayPattern = DayPattern.daily,
    Set<int> weekdays = const {},
    this.everyNDays = 2,
    this.cycleOnDays = 21,
    this.cycleOffDays = 7,
    List<DoseTime> times = const [],
  }) : startDate = dateOnly(startDate),
       endDate = endDate == null ? null : dateOnly(endDate),
       weekdays = Set.unmodifiable(weekdays),
       times = List.unmodifiable([...times]..sort());

  final DateTime startDate;
  final DurationType durationType;

  /// Day count for [DurationType.days], dose count for [DurationType.doseCount].
  final int? durationValue;
  final DateTime? endDate;

  final DayPattern dayPattern;
  final Set<int> weekdays;
  final int everyNDays;
  final int cycleOnDays;
  final int cycleOffDays;

  /// Intake times within an active day, sorted by time.
  final List<DoseTime> times;

  /// Returns a list of problems; empty when the rule is usable.
  List<ScheduleProblem> validate() {
    final problems = <ScheduleProblem>[];
    if (dayPattern != DayPattern.asNeeded && times.isEmpty) {
      problems.add(ScheduleProblem.noTimes);
    }
    final minutes = times.map((t) => t.minuteOfDay).toList();
    if (minutes.toSet().length != minutes.length) {
      problems.add(ScheduleProblem.duplicateTimes);
    }
    if (times.any((t) => t.dose <= 0)) {
      problems.add(ScheduleProblem.badDose);
    }
    switch (dayPattern) {
      case DayPattern.weekdays when weekdays.isEmpty:
        problems.add(ScheduleProblem.noWeekdays);
      case DayPattern.everyNDays when everyNDays < 1:
        problems.add(ScheduleProblem.badEveryN);
      case DayPattern.cycle when cycleOnDays < 1 || cycleOffDays < 0:
        problems.add(ScheduleProblem.badCycle);
      default:
        break;
    }
    switch (durationType) {
      case DurationType.days || DurationType.doseCount
          when (durationValue ?? 0) < 1:
        problems.add(ScheduleProblem.badDuration);
      case DurationType.untilDate
          when endDate == null || endDate!.isBefore(startDate):
        problems.add(ScheduleProblem.badDuration);
      default:
        break;
    }
    return problems;
  }

  bool get isValid => validate().isEmpty;

  /// Whether [day] matches the day pattern, ignoring the duration limit.
  bool _matchesPattern(DateTime day) {
    final offset = daysBetween(startDate, day);
    if (offset < 0) return false;
    switch (dayPattern) {
      case DayPattern.daily:
        return true;
      case DayPattern.weekdays:
        return weekdays.contains(day.weekday);
      case DayPattern.everyNDays:
        return everyNDays >= 1 && offset % everyNDays == 0;
      case DayPattern.cycle:
        final period = cycleOnDays + cycleOffDays;
        return period > 0 && offset % period < cycleOnDays;
      case DayPattern.asNeeded:
        return false;
    }
  }

  /// Last day (inclusive) the schedule can be active on, or null if open-ended.
  /// For [DurationType.doseCount] the end depends on the pattern and is
  /// computed by walking the calendar.
  DateTime? get lastDay {
    switch (durationType) {
      case DurationType.forever:
        return null;
      case DurationType.days:
        return addDays(startDate, (durationValue ?? 1) - 1);
      case DurationType.untilDate:
        return endDate;
      case DurationType.doseCount:
        final limit = durationValue ?? 0;
        if (limit <= 0 || times.isEmpty || dayPattern == DayPattern.asNeeded) {
          return startDate;
        }
        var count = 0;
        // Safety bound: about 30 years of calendar.
        for (var i = 0; i < 11000; i++) {
          final day = addDays(startDate, i);
          if (_matchesPattern(day)) {
            count += times.length;
            if (count >= limit) return day;
          }
        }
        return null;
    }
  }

  /// Planned doses with `from <= at < to`, sorted by time.
  List<DoseOccurrence> occurrences(DateTime from, DateTime to) {
    if (!to.isAfter(from) || times.isEmpty) return const [];
    if (dayPattern == DayPattern.asNeeded) return const [];

    final last = lastDay;
    var day = dateOnly(from).isBefore(startDate) ? startDate : dateOnly(from);
    final lastCandidate = dateOnly(to);
    final result = <DoseOccurrence>[];

    // For dose-count schedules, count doses already used before [day].
    int? remaining;
    if (durationType == DurationType.doseCount) {
      remaining = durationValue ?? 0;
      for (var d = startDate; d.isBefore(day); d = addDays(d, 1)) {
        if (_matchesPattern(d)) remaining = remaining! - times.length;
      }
    }

    for (; !day.isAfter(lastCandidate); day = addDays(day, 1)) {
      if (last != null && day.isAfter(last)) break;
      if (!_matchesPattern(day)) continue;
      for (final t in times) {
        if (remaining != null) {
          if (remaining <= 0) return result;
          remaining--;
        }
        final at = DateTime(day.year, day.month, day.day, t.hour, t.minute);
        if (!at.isBefore(from) && at.isBefore(to)) {
          result.add(DoseOccurrence(at, t.dose));
        }
      }
    }
    return result;
  }

  /// The first planned dose at or after [from], looking ahead up to [horizon].
  DoseOccurrence? nextAfter(
    DateTime from, {
    Duration horizon = const Duration(days: 400),
  }) {
    final list = occurrences(from, from.add(horizon));
    return list.isEmpty ? null : list.first;
  }

  /// Total amount scheduled per active day.
  double get dailyAmount => times.fold(0, (sum, t) => sum + t.dose);

  ScheduleRule copyWith({
    DateTime? startDate,
    DurationType? durationType,
    int? durationValue,
    DateTime? endDate,
    DayPattern? dayPattern,
    Set<int>? weekdays,
    int? everyNDays,
    int? cycleOnDays,
    int? cycleOffDays,
    List<DoseTime>? times,
  }) => ScheduleRule(
    startDate: startDate ?? this.startDate,
    durationType: durationType ?? this.durationType,
    durationValue: durationValue ?? this.durationValue,
    endDate: endDate ?? this.endDate,
    dayPattern: dayPattern ?? this.dayPattern,
    weekdays: weekdays ?? this.weekdays,
    everyNDays: everyNDays ?? this.everyNDays,
    cycleOnDays: cycleOnDays ?? this.cycleOnDays,
    cycleOffDays: cycleOffDays ?? this.cycleOffDays,
    times: times ?? this.times,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'start': _ymd(startDate),
    'durationType': durationType.name,
    'durationValue': durationValue,
    'end': endDate == null ? null : _ymd(endDate!),
    'pattern': dayPattern.name,
    'weekdays': (weekdays.toList()..sort()),
    'everyN': everyNDays,
    'cycleOn': cycleOnDays,
    'cycleOff': cycleOffDays,
    'times': times.map((t) => t.toJson()).toList(),
  };

  factory ScheduleRule.fromJson(Map<String, dynamic> json) => ScheduleRule(
    startDate: _parseYmd(json['start'] as String),
    durationType: DurationType.values.byName(json['durationType'] as String),
    durationValue: json['durationValue'] as int?,
    endDate: json['end'] == null ? null : _parseYmd(json['end'] as String),
    dayPattern: DayPattern.values.byName(json['pattern'] as String),
    weekdays: {...(json['weekdays'] as List).cast<int>()},
    everyNDays: json['everyN'] as int? ?? 2,
    cycleOnDays: json['cycleOn'] as int? ?? 21,
    cycleOffDays: json['cycleOff'] as int? ?? 7,
    times: [
      for (final t in json['times'] as List)
        DoseTime.fromJson((t as Map).cast<String, dynamic>()),
    ],
  );

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _parseYmd(String s) {
    final p = s.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }
}

enum ScheduleProblem {
  noTimes,
  duplicateTimes,
  badDose,
  noWeekdays,
  badEveryN,
  badCycle,
  badDuration,
}
