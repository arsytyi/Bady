import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/format.dart';
import '../domain/reminder_plan.dart';
import '../domain/schedule_rule.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'medication_detail_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Today's planned doses grouped by time. Marking doses as taken comes in
/// the next step; for now this is a read-only agenda.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final plan = ref.watch(activePlanProvider);
    final meds = {
      for (final p in plan.value ?? const []) p.medication.id: p.medication,
    };
    final now = DateTime.now();
    final today = dateOnly(now);
    final reminders = buildReminders(
      toPlanEntries(plan.value ?? const []),
      from: today,
      to: addDays(today, 1),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navToday),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(DateFormat.MMMMEEEEd(locale).format(now)),
          ),
        ),
      ),
      body: plan.isLoading
          ? const Center(child: CircularProgressIndicator())
          : reminders.isEmpty
          ? EmptyState(
              icon: Icons.event_available_outlined,
              title: l.todayEmpty,
              subtitle: l.todayHint,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: Spacing.xl),
              children: [
                for (final r in reminders) ...[
                  _TimeHeader(at: r.at, past: r.at.isBefore(now)),
                  for (final item in r.items)
                    ListTile(
                      leading: MedAvatar(
                        color: Color(meds[item.medicationId]?.color ?? 0),
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        [
                          formatDoseWithUnit(item.dose, item.unit),
                          if (meds[item.medicationId] case final m?
                              when m.meal.index != 0)
                            l.mealName(m.meal.name),
                        ].join(' · '),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MedicationDetailScreen(id: item.medicationId),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _TimeHeader extends StatelessWidget {
  const _TimeHeader({required this.at, required this.past});

  final DateTime at;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.lg,
        Spacing.lg,
        Spacing.xs,
      ),
      child: Row(
        children: [
          Text(
            formatTime(at.hour, at.minute),
            style: timeStyle(context, muted: past),
          ),
          if (past) ...[
            const SizedBox(width: 8),
            Text(
              l.timePassed,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
