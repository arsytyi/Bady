import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'medication_detail_screen.dart';
import 'medication_form_screen.dart';
import 'pill_icon.dart';
import 'theme.dart';
import 'widgets.dart';

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final meds = ref.watch(medicationsProvider);
    final archived = ref.watch(archivedMedicationsProvider).value ?? const [];

    void add() => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MedicationFormScreen()),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.navMedications)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: add,
        icon: const Icon(Icons.add),
        label: Text(l.addMedication),
      ),
      body: meds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty && archived.isEmpty
            ? EmptyState(
                icon: Icons.medication_outlined,
                title: l.medicationsEmpty,
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: Spacing.fabClearance),
                children: [
                  for (final m in list) _MedTile(m),
                  if (archived.isNotEmpty) ...[
                    SectionTitle(l.archivedSection),
                    for (final m in archived) _MedTile(m),
                  ],
                ],
              ),
      ),
    );
  }
}

class _MedTile extends StatelessWidget {
  const _MedTile(this.med);

  final Medication med;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final subtitle = [
      med.kind.index == 0 ? l.kindMedicine : l.kindSupplement,
      l.formName(med.form.name),
      if (med.notes.trim().isNotEmpty) med.notes.trim().split('\n').first,
    ].join(' · ');
    return Opacity(
      opacity: med.archived ? 0.6 : 1,
      child: ListTile(
        leading: PillAvatar(med),
        title: Text(med.name),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MedicationDetailScreen(id: med.id),
          ),
        ),
      ),
    );
  }
}
