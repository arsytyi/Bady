import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/format.dart';
import '../domain/interactions.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'theme.dart';
import 'widgets.dart';

/// Text lines describing [issue] from medication [id]'s point of view.
String compatText(InteractionIssue issue, int id, AppLocalizations l) {
  final lang = l.localeName.split('_').first;
  final other = issue.other(id).name;
  final r = issue.rule;
  final head = switch (r.type) {
    RuleType.separate => l.compatSeparate(other, r.hours),
    RuleType.avoid => l.compatAvoid(other),
    RuleType.together => l.compatTogether(other),
  };
  final parts = [head, r.text(lang)];
  if (r.type == RuleType.separate &&
      issue.timeA != null &&
      issue.timeB != null) {
    final mine = issue.a.id == id ? issue.timeA! : issue.timeB!;
    final theirs = issue.a.id == id ? issue.timeB! : issue.timeA!;
    parts.add(
      l.compatNow(
        formatTime(mine.hour, mine.minute),
        formatTime(theirs.hour, theirs.minute),
      ),
    );
    if (issue.suggestionFor(id) case final t?) {
      parts.add(l.compatSuggest(formatTime(t.hour, t.minute)));
    }
  }
  return parts.join(' ');
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue, required this.medicationId});

  final InteractionIssue issue;
  final int medicationId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final warn = issue.isWarning;
    return ListTile(
      leading: Icon(
        warn ? Icons.warning_amber_rounded : Icons.thumb_up_alt_outlined,
        color: warn ? scheme.error : scheme.primary,
      ),
      title: Text(compatText(issue, medicationId, l)),
    );
  }
}

/// Compatibility notes for one medication; nothing when there are none.
class CompatSection extends ConsumerWidget {
  const CompatSection({super.key, required this.medicationId});

  final int medicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final issues = [
      for (final i in ref.watch(interactionIssuesProvider))
        if (i.involves(medicationId)) i,
    ]..sort((a, b) => (a.isWarning ? 0 : 1).compareTo(b.isWarning ? 0 : 1));
    if (issues.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l.compatTitle),
        for (final i in issues)
          _IssueTile(issue: i, medicationId: medicationId),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Text(
            l.compatDisclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Asks before saving a schedule that creates [issues]. True to save.
Future<bool> confirmCompat(
  BuildContext context,
  List<InteractionIssue> issues,
  int medicationId,
) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(l.compatWarningTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final i in issues) ...[
              Text(compatText(i, medicationId, l)),
              const SizedBox(height: Spacing.sm),
            ],
            Text(
              l.compatDisclaimer,
              style: Theme.of(dialog).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l.compatSaveAnyway),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(l.compatChangeTime),
        ),
      ],
    ),
  );
  return ok ?? false;
}
