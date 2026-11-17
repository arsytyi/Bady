import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import '../domain/format.dart';
import '../domain/schedule_rule.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'widgets.dart';

class ScheduleEditorScreen extends ConsumerStatefulWidget {
  const ScheduleEditorScreen({
    super.key,
    required this.medication,
    this.existing,
  });

  final Medication medication;
  final Schedule? existing;

  @override
  ConsumerState<ScheduleEditorScreen> createState() =>
      _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends ConsumerState<ScheduleEditorScreen> {
  late ScheduleRule _rule;
  bool _showProblems = false;

  @override
  void initState() {
    super.initState();
    _rule =
        widget.existing?.rule ??
        ScheduleRule(
          startDate: DateTime.now(),
          times: const [DoseTime(hour: 9, minute: 0)],
        );
  }

  void _update(ScheduleRule r) => setState(() => _rule = r);

  /// copyWith can't clear nullable fields, so rebuild for duration changes.
  void _setDuration(DurationType type, {int? value, DateTime? end}) {
    _update(
      ScheduleRule(
        startDate: _rule.startDate,
        durationType: type,
        durationValue: value,
        endDate: end,
        dayPattern: _rule.dayPattern,
        weekdays: _rule.weekdays,
        everyNDays: _rule.everyNDays,
        cycleOnDays: _rule.cycleOnDays,
        cycleOffDays: _rule.cycleOffDays,
        times: _rule.times,
      ),
    );
  }

  Future<void> _save() async {
    if (!_rule.isValid) {
      setState(() => _showProblems = true);
      return;
    }
    final db = ref.read(databaseProvider);
    final nav = Navigator.of(context);
    if (widget.existing case final s?) {
      await db.updateSchedule(s.id, _rule);
    } else {
      await db.insertSchedule(widget.medication.id, _rule);
    }
    nav.pop();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l.deleteScheduleTitle,
      confirmLabel: l.delete,
      cancelLabel: l.cancel,
    );
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    await ref.read(databaseProvider).deleteSchedule(widget.existing!.id);
    nav.pop();
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first ?? DateTime(2020),
        lastDate: DateTime(2100),
      );

  Future<void> _editTime(int? index) async {
    final current = index == null
        ? DoseTime(
            hour: _rule.times.isEmpty
                ? 9
                : (_rule.times.last.hour + 4).clamp(0, 23),
            minute: 0,
            dose: _rule.times.isEmpty ? 1 : _rule.times.last.dose,
          )
        : _rule.times[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final times = [..._rule.times];
    final updated = current.copyWith(hour: picked.hour, minute: picked.minute);
    if (index == null) {
      times.add(updated);
    } else {
      times[index] = updated;
    }
    _update(_rule.copyWith(times: times));
  }

  void _setDose(int index, double dose) {
    final times = [..._rule.times];
    times[index] = times[index].copyWith(dose: dose);
    _update(_rule.copyWith(times: times));
  }

  Future<void> _generateTimes() async {
    final result = await showDialog<List<DoseTime>>(
      context: context,
      builder: (_) => _IntervalDialog(
        dose: _rule.times.isEmpty ? 1 : _rule.times.first.dose,
      ),
    );
    if (result != null && result.isNotEmpty) {
      _update(_rule.copyWith(times: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unit = widget.medication.unit;
    final problems = _rule.validate();
    final asNeeded = _rule.dayPattern == DayPattern.asNeeded;

    return Scaffold(
      appBar: AppBar(
        title: Text('${l.scheduleTitle}: ${widget.medication.name}'),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_showProblems && problems.isNotEmpty)
            Card(
              margin: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in problems)
                      Text(
                        '• ${problemText(p, l)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Days
          SectionTitle(l.sectionDays),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (pattern, label) in [
                  (DayPattern.daily, l.patternDaily),
                  (DayPattern.weekdays, l.patternWeekdays),
                  (DayPattern.everyNDays, l.patternEveryN),
                  (DayPattern.cycle, l.patternCycle),
                  (DayPattern.asNeeded, l.patternAsNeeded),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _rule.dayPattern == pattern,
                    onSelected: (_) {
                      var r = _rule.copyWith(dayPattern: pattern);
                      if (pattern == DayPattern.weekdays &&
                          r.weekdays.isEmpty) {
                        r = r.copyWith(weekdays: {_rule.startDate.weekday});
                      }
                      _update(r);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._patternDetails(l, locale),

          // Times
          if (!asNeeded) ...[
            SectionTitle(
              l.sectionTimes,
              trailing: TextButton.icon(
                onPressed: _generateTimes,
                icon: const Icon(Icons.repeat, size: 18),
                label: Text(l.generateTimes),
              ),
            ),
            for (final (i, t) in _rule.times.indexed)
              ListTile(
                key: ValueKey('time-$i-${t.minuteOfDay}'),
                leading: const Icon(Icons.schedule),
                title: InkWell(
                  onTap: () => _editTime(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      formatTime(t.hour, t.minute),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                subtitle: Row(
                  children: [
                    Text('${l.dose}: '),
                    _DoseStepper(
                      value: t.dose,
                      onChanged: (v) => _setDose(i, v),
                    ),
                    if (unit.isNotEmpty) Text(' $unit'),
                  ],
                ),
                trailing: IconButton(
                  tooltip: l.removeTime,
                  icon: const Icon(Icons.close),
                  onPressed: () => _update(
                    _rule.copyWith(times: [..._rule.times]..removeAt(i)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _editTime(null),
                  icon: const Icon(Icons.add),
                  label: Text(l.addTime),
                ),
              ),
            ),
          ],

          // Duration
          SectionTitle(l.sectionDuration),
          ListTile(
            leading: const Icon(Icons.play_arrow_outlined),
            title: Text(l.startDate),
            trailing: Text(formatDate(_rule.startDate, locale)),
            onTap: () async {
              final d = await _pickDate(_rule.startDate);
              if (d != null) _update(_rule.copyWith(startDate: d));
            },
          ),
          if (!asNeeded) ..._durationDetails(l, locale),

          // Preview
          if (!asNeeded) ...[
            SectionTitle(l.preview),
            _Preview(rule: _rule, unit: unit),
          ],
        ],
      ),
    );
  }

  List<Widget> _patternDetails(AppLocalizations l, String locale) {
    switch (_rule.dayPattern) {
      case DayPattern.daily:
        return const [];
      case DayPattern.asNeeded:
        return [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.asNeededHint),
          ),
        ];
      case DayPattern.weekdays:
        final names = weekdayNames(locale);
        return [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(names[d - 1]),
                    selected: _rule.weekdays.contains(d),
                    onSelected: (on) {
                      final set = {..._rule.weekdays};
                      on ? set.add(d) : set.remove(d);
                      _update(_rule.copyWith(weekdays: set));
                    },
                  ),
              ],
            ),
          ),
        ];
      case DayPattern.everyNDays:
        return [
          _NumberRow(
            label: l.everyNLabel,
            value: _rule.everyNDays,
            min: 1,
            onChanged: (v) => _update(_rule.copyWith(everyNDays: v)),
          ),
        ];
      case DayPattern.cycle:
        return [
          _NumberRow(
            label: l.cycleOn,
            value: _rule.cycleOnDays,
            min: 1,
            onChanged: (v) => _update(_rule.copyWith(cycleOnDays: v)),
          ),
          _NumberRow(
            label: l.cycleOff,
            value: _rule.cycleOffDays,
            min: 0,
            onChanged: (v) => _update(_rule.copyWith(cycleOffDays: v)),
          ),
        ];
    }
  }

  List<Widget> _durationDetails(AppLocalizations l, String locale) {
    final type = _rule.durationType;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (t, label) in [
              (DurationType.forever, l.durForever),
              (DurationType.days, l.durDays),
              (DurationType.untilDate, l.durUntil),
              (DurationType.doseCount, l.durDoses),
            ])
              ChoiceChip(
                label: Text(label),
                selected: type == t,
                onSelected: (_) => switch (t) {
                  DurationType.forever => _setDuration(t),
                  DurationType.days => _setDuration(t, value: 30),
                  DurationType.doseCount => _setDuration(t, value: 30),
                  DurationType.untilDate => _setDuration(
                    t,
                    end: addDays(_rule.startDate, 29),
                  ),
                },
              ),
          ],
        ),
      ),
      if (type == DurationType.days || type == DurationType.doseCount)
        _NumberRow(
          label: type == DurationType.days ? l.durDays : l.durDoses,
          value: _rule.durationValue ?? 1,
          min: 1,
          onChanged: (v) => _setDuration(type, value: v),
        ),
      if (type == DurationType.untilDate)
        ListTile(
          leading: const Icon(Icons.stop_outlined),
          title: Text(l.endDate),
          trailing: Text(
            _rule.endDate == null ? '—' : formatDate(_rule.endDate!, locale),
          ),
          onTap: () async {
            final d = await _pickDate(
              _rule.endDate ?? _rule.startDate,
              first: _rule.startDate,
            );
            if (d != null) _setDuration(type, end: d);
          },
        ),
    ];
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.rule, required this.unit});

  final ScheduleRule rule;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = dateOnly(DateTime.now());
    final list = rule.isValid
        ? rule.occurrences(today, addDays(today, 7))
        : const <DoseOccurrence>[];
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(l.previewEmpty),
      );
    }
    final byDay = <DateTime, List<DoseOccurrence>>{};
    for (final o in list) {
      byDay.putIfAbsent(dateOnly(o.at), () => []).add(o);
    }
    final dayFormat = DateFormat.MMMEd(locale);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in byDay.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: Text(dayFormat.format(e.key))),
                  Expanded(
                    child: Text(
                      e.value
                          .map(
                            (o) =>
                                '${formatTime(o.at.hour, o.at.minute)} (${formatDoseWithUnit(o.dose, unit)})',
                          )
                          .join(', '),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9999,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: AppLocalizations.of(context).decrease,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 56,
          child: TextFormField(
            key: ValueKey(value),
            initialValue: '$value',
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (s) {
              final v = int.tryParse(s);
              if (v != null && v >= min && v <= max) onChanged(v);
            },
          ),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context).increase,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    ),
  );
}

/// Dose in steps of 0.25 (quarter tablets), tap the value to type any number.
class _DoseStepper extends StatelessWidget {
  const _DoseStepper({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: AppLocalizations.of(context).decrease,
        icon: const Icon(Icons.remove, size: 18),
        onPressed: value > 0.25 ? () => onChanged(value - 0.25) : null,
      ),
      InkWell(
        onTap: () async {
          final controller = TextEditingController(text: formatDose(value));
          final result = await showDialog<double>(
            context: context,
            builder: (context) => AlertDialog(
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    double.tryParse(controller.text.replaceAll(',', '.')),
                  ),
                  child: Text(AppLocalizations.of(context).apply),
                ),
              ],
            ),
          );
          controller.dispose();
          if (result != null && result > 0) onChanged(result);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            formatDose(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      IconButton(
        tooltip: AppLocalizations.of(context).increase,
        icon: const Icon(Icons.add, size: 18),
        onPressed: () => onChanged(value + 0.25),
      ),
    ],
  );
}

class _IntervalDialog extends StatefulWidget {
  const _IntervalDialog({required this.dose});

  final double dose;

  @override
  State<_IntervalDialog> createState() => _IntervalDialogState();
}

class _IntervalDialogState extends State<_IntervalDialog> {
  int _every = 8;
  TimeOfDay _from = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _until = const TimeOfDay(hour: 22, minute: 0);

  List<DoseTime> get _times => intervalTimes(
    everyHours: _every,
    fromHour: _from.hour,
    fromMinute: _from.minute,
    untilHour: _until.hour,
    untilMinute: _until.minute,
    dose: widget.dose,
  );

  Future<TimeOfDay?> _pick(TimeOfDay initial) => showTimePicker(
    context: context,
    initialTime: initial,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.generateTimes),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NumberRow(
            label: l.everyHours,
            value: _every,
            min: 1,
            max: 24,
            onChanged: (v) => setState(() => _every = v),
          ),
          ListTile(
            title: Text(l.fromTime),
            trailing: Text(formatTime(_from.hour, _from.minute)),
            onTap: () async {
              final t = await _pick(_from);
              if (t != null) setState(() => _from = t);
            },
          ),
          ListTile(
            title: Text(l.untilTime),
            trailing: Text(formatTime(_until.hour, _until.minute)),
            onTap: () async {
              final t = await _pick(_until);
              if (t != null) setState(() => _until = t);
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _times.map((t) => formatTime(t.hour, t.minute)).join(', '),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _times),
          child: Text(l.apply),
        ),
      ],
    );
  }
}
