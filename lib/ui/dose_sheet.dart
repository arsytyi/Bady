import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/dose_plan.dart';
import '../domain/format.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/dose_actions.dart';
import 'theme.dart';
import 'today_screen.dart';

List<DoseRef> _refs(Iterable<DoseSlot> slots) => [
  for (final s in slots)
    if (s.scheduledAt != null)
      (medicationId: s.medicationId, scheduledAt: s.scheduledAt!, dose: s.dose),
];

void _snack(BuildContext context, String text, {VoidCallback? onUndo}) {
  final l = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 4),
        action: onUndo == null
            ? null
            : SnackBarAction(label: l.undo, onPressed: onUndo),
      ),
    );
}

Future<void> _afterChange(WidgetRef ref) =>
    ref.read(reminderSyncProvider).resync();

/// Marks [slots] taken with a confirmation and an undo.
Future<void> takeSlots(
  BuildContext context,
  WidgetRef ref,
  List<DoseSlot> slots,
) async {
  final l = AppLocalizations.of(context);
  final actions = ref.read(doseActionsProvider);
  final refs = _refs(slots.where((s) => s.isPending));
  if (refs.isEmpty) return;
  HapticFeedback.lightImpact();
  await actions.take(refs);
  await _afterChange(ref);
  if (!context.mounted) return;
  _snack(
    context,
    l.stateTaken,
    onUndo: () async {
      await actions.undo(refs);
      await _afterChange(ref);
    },
  );
}

/// Bottom sheet with Taken / Snooze / Skip for one or more doses at the
/// same time, plus undo for doses already marked.
Future<void> showDoseSheet(
  BuildContext context,
  WidgetRef ref,
  List<DoseSlot> slots,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _DoseSheet(slots: slots, parentContext: context),
  );
}

class _DoseSheet extends ConsumerWidget {
  const _DoseSheet({required this.slots, required this.parentContext});

  final List<DoseSlot> slots;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final meds = ref.watch(allMedicationsProvider).value ?? const {};
    final settings = ref.watch(reminderSettingsProvider);
    final actions = ref.read(doseActionsProvider);
    final pending = slots.where((s) => s.isPending).toList();
    final logged = slots.where((s) => s.isLogged).toList();
    final time = slots.first.time;
    final isFutureDay = dateIsAfterToday(time);

    Future<void> run(Future<void> Function() action, String message) async {
      Navigator.of(context).pop();
      await action();
      await _afterChange(ref);
      if (parentContext.mounted) _snack(parentContext, message);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              formatTime(time.hour, time.minute),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            for (final s in slots)
              if (meds[s.medicationId] case final m?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: theme.textTheme.titleMedium),
                            Text(
                              [
                                formatDoseWithUnit(s.dose, m.unit),
                                if (m.meal.index != 0) l.mealName(m.meal.name),
                              ].join(' · '),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (m.notes.isNotEmpty)
                              Text(
                                m.notes,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      StatusChip(slot: s),
                    ],
                  ),
                ),
            const SizedBox(height: Spacing.lg),
            if (pending.isNotEmpty && !isFutureDay) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.check),
                label: Text(pending.length > 1 ? l.takeAll : l.actionTaken),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  run(() => actions.take(_refs(pending)), l.stateTaken);
                },
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.snooze),
                      label: Text(l.snoozeFor(settings.snoozeMinutes)),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        final until = await actions.snooze(_refs(pending));
                        await _afterChange(ref);
                        if (parentContext.mounted) {
                          _snack(
                            parentContext,
                            l.snackSnoozed(
                              formatTime(until.hour, until.minute),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.block),
                      label: Text(l.actionSkip),
                      onPressed: () => run(
                        () => actions.skip(_refs(pending)),
                        l.stateSkipped,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (logged.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.undo),
                label: Text(l.undoMark),
                onPressed: () async {
                  Navigator.of(context).pop();
                  final db = ref.read(databaseProvider);
                  for (final s in logged) {
                    if (s.scheduledAt == null) {
                      await db.deleteEvent(s.eventId!);
                    } else {
                      await db.clearDose(s.medicationId, s.scheduledAt!);
                    }
                  }
                  await _afterChange(ref);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool dateIsAfterToday(DateTime t) {
  final now = DateTime.now();
  return DateTime(
    t.year,
    t.month,
    t.day,
  ).isAfter(DateTime(now.year, now.month, now.day));
}
