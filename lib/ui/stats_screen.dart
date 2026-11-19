import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import '../domain/schedule_rule.dart';
import '../domain/stats.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'history_screen.dart';
import 'pill_icon.dart';
import 'theme.dart';
import 'widgets.dart';

/// Dose log for the last year, for statistics and history.
final yearLogProvider = StreamProvider<List<DoseEvent>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(databaseProvider)
      .watchEventsBetween(
        addDays(dateOnly(now), -366),
        addDays(dateOnly(now), 1),
      );
});

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _period = 7;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final plan = ref.watch(activePlanProvider);
    final log = ref.watch(yearLogProvider);
    final meds = ref.watch(allMedicationsProvider).value ?? const {};

    Widget body;
    if (plan.isLoading || log.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final stats = computeStats(
        entries: toPlanEntries(plan.value ?? const []),
        logged: [
          for (final e in log.value ?? const <DoseEvent>[]) e.toLogged(),
        ],
        now: DateTime.now(),
        periodDays: _period,
      );
      body = stats.isEmpty
          ? EmptyState(icon: Icons.insights_outlined, title: l.statsEmpty)
          : ListView(
              padding: const EdgeInsets.only(bottom: Spacing.xl),
              children: [
                _SummaryCard(stats: stats, period: _period),
                SectionTitle(l.statsByDay),
                _DailyChart(days: stats.days),
                SectionTitle(l.statsByMedication),
                for (final e
                    in stats.byMedication.entries.toList()..sort(
                      (a, b) => (meds[a.key]?.name ?? '').compareTo(
                        meds[b.key]?.name ?? '',
                      ),
                    ))
                  if (meds[e.key] case final m?)
                    _MedicationRow(medication: m, counts: e.value),
              ],
            );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navStats),
        actions: [
          IconButton(
            tooltip: l.historyTitle,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final d in const [7, 30, 90])
                    ButtonSegment(value: d, label: Text(l.statsPeriod(d))),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

int _percent(double? v) => ((v ?? 0) * 100).round();

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats, required this.period});

  final Stats stats;
  final int period;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = stats.total;
    final onCard = scheme.onSecondaryContainer;

    Widget count(IconData icon, String label, int value) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: onCard),
          const SizedBox(height: Spacing.xs),
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              color: onCard,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(color: onCard),
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.all(Spacing.lg),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.statsAdherence,
              style: theme.textTheme.titleSmall?.copyWith(color: onCard),
            ),
            Text(
              '${_percent(t.adherence)}%',
              style: theme.textTheme.displayMedium?.copyWith(
                color: onCard,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              l.statsSummary(period, t.taken, t.total, _percent(t.adherence)),
              style: theme.textTheme.bodyMedium?.copyWith(color: onCard),
            ),
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                count(Icons.check_circle_outline, l.statsTaken, t.taken),
                count(Icons.block, l.statsSkipped, t.skipped),
                count(Icons.error_outline, l.statsMissed, t.missed),
              ],
            ),
            if (stats.streak > 0) ...[
              const SizedBox(height: Spacing.lg),
              Row(
                children: [
                  Icon(Icons.local_fire_department, color: onCard),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      l.statsStreak(stats.streak),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: onCard,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One bar per day: share of due doses taken. Tap a bar for details.
class _DailyChart extends StatefulWidget {
  const _DailyChart({required this.days});

  final List<DayStat> days;

  @override
  State<_DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<_DailyChart> {
  int? _selected;

  @override
  void didUpdateWidget(_DailyChart old) {
    super.didUpdateWidget(old);
    if (old.days.length != widget.days.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = widget.days;
    final selected = _selected ?? days.length - 1;
    final sel = days[selected];
    final dateFmt = DateFormat.MMMEd(locale);
    final short = DateFormat.Md(locale);
    const chartHeight = 140.0;

    String detail(DayStat d) => d.counts.total == 0
        ? '${dateFmt.format(d.day)}: —'
        : '${dateFmt.format(d.day)}: '
              '${l.statsOfTotal(d.counts.taken, d.counts.total)} '
              '(${_percent(d.counts.adherence)}%)';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Readout of the selected day (also announced to screen readers).
          Semantics(
            liveRegion: true,
            child: Text(
              detail(sel),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            l.statsChartHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                // Recessive gridlines at 0, 50 and 100%.
                for (final f in const [0.0, 0.5, 1.0])
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: f * (chartHeight - 1),
                    child: Container(
                      height: 1,
                      color: scheme.outlineVariant.withValues(
                        alpha: f == 0 ? 1 : 0.5,
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, d) in days.indexed)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == selected,
                          label: detail(d),
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _selected = i),
                            child: SizedBox(
                              height: chartHeight,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: days.length > 31 ? 0.5 : 1,
                                  ),
                                  child: _Bar(
                                    fraction: d.counts.adherence,
                                    height: chartHeight,
                                    selected: i == selected,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in [days.first, days[days.length ~/ 2], days.last])
                Text(
                  short.format(d.day),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.height,
    required this.selected,
  });

  /// Null when nothing was due that day.
  final double? fraction;
  final double height;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (fraction == null) {
      return Container(
        height: 4,
        decoration: BoxDecoration(
          color: scheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    final h = (fraction! * (height - 2)).clamp(4.0, height);
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary
            : scheme.primary.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  const _MedicationRow({required this.medication, required this.counts});

  final Medication medication;
  final DoseCounts counts;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pct = _percent(counts.adherence);
    return ListTile(
      leading: PillAvatar(medication),
      title: Text(medication.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Spacing.xs),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: counts.adherence ?? 0,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$pct%',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            l.statsOfTotal(counts.taken, counts.total),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
