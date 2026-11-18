import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import '../domain/enums.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'medication_detail_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Create or edit a medication's details (not its schedules).
class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen({super.key, this.existing});

  final Medication? existing;

  @override
  ConsumerState<MedicationFormScreen> createState() =>
      _MedicationFormScreenState();
}

class _MedicationFormScreenState extends ConsumerState<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _notes;
  late MedKind _kind;
  late MedForm _form;
  late MealRelation _meal;
  late int _color;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _name = TextEditingController(text: m?.name ?? '');
    _unit = TextEditingController(text: m?.unit ?? '');
    _notes = TextEditingController(text: m?.notes ?? '');
    _kind = m?.kind ?? MedKind.supplement;
    _form = m?.form ?? MedForm.tablet;
    _meal = m?.meal ?? MealRelation.any;
    _color = m?.color ?? medColors.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final entry = MedicationsCompanion(
      name: Value(_name.text.trim()),
      kind: Value(_kind),
      form: Value(_form),
      unit: Value(_unit.text.trim()),
      meal: Value(_meal),
      notes: Value(_notes.text.trim()),
      color: Value(_color),
    );
    final nav = Navigator.of(context);
    if (widget.existing case final m?) {
      await db.updateMedication(m.id, entry);
      nav.pop();
    } else {
      final id = await db.insertMedication(entry);
      nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => MedicationDetailScreen(id: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? l.addMedication : l.editMedication,
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            TextFormField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: '${l.fieldName} *',
                helperText: l.requiredHint,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.fieldNameRequired : null,
            ),
            const SizedBox(height: Spacing.lg),
            SegmentedButton<MedKind>(
              segments: [
                ButtonSegment(
                  value: MedKind.medicine,
                  label: Text(l.kindMedicine),
                ),
                ButtonSegment(
                  value: MedKind.supplement,
                  label: Text(l.kindSupplement),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<MedForm>(
                    initialValue: _form,
                    decoration: InputDecoration(labelText: l.fieldForm),
                    items: [
                      for (final f in MedForm.values)
                        DropdownMenuItem(
                          value: f,
                          child: Text(l.formName(f.name)),
                        ),
                    ],
                    onChanged: (f) => setState(() => _form = f!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    decoration: InputDecoration(
                      labelText: l.fieldUnit,
                      hintText: l.fieldUnitHint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            DropdownButtonFormField<MealRelation>(
              initialValue: _meal,
              decoration: InputDecoration(labelText: l.fieldMeal),
              items: [
                for (final m in MealRelation.values)
                  DropdownMenuItem(value: m, child: Text(l.mealName(m.name))),
              ],
              onChanged: (m) => setState(() => _meal = m!),
            ),
            const SizedBox(height: Spacing.lg),
            TextFormField(
              controller: _notes,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.fieldNotes,
                hintText: l.fieldNotesHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(l.fieldColor, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, c) in medColors.indexed)
                  Semantics(
                    button: true,
                    selected: c == _color,
                    label: l.colorOption(i + 1),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 3,
                            color: c == _color
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                          ),
                        ),
                        child: c == _color
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
