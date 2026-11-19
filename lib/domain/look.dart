/// How a medication looks and is measured: pill shape, colors, dose units.
library;

import 'enums.dart';

/// Stored by index: only append new values at the end.
enum PillShape {
  roundTablet,
  ovalTablet,
  capsule,
  softgel,
  dropper,
  bottle,
  sachet,
  syringe,
  spray,
}

PillShape defaultShapeFor(MedForm form) => switch (form) {
  MedForm.tablet => PillShape.roundTablet,
  MedForm.capsule => PillShape.capsule,
  MedForm.drops => PillShape.dropper,
  MedForm.liquid => PillShape.bottle,
  MedForm.powder => PillShape.sachet,
  MedForm.injection => PillShape.syringe,
  MedForm.spray => PillShape.spray,
  MedForm.other => PillShape.roundTablet,
};

/// Built-in dose units. Stored in the database as `@<name>`; anything else
/// is free text the user typed.
enum DoseUnit {
  tablet,
  capsule,
  drop,
  ml,
  mg,
  g,
  mcg,
  iu,
  units,
  sachet,
  teaspoon,
  tablespoon,
  scoop,
  ampoule,
  spray,
  dose,
  piece,
}

const _unitPrefix = '@';

String storeUnit(DoseUnit u) => '$_unitPrefix${u.name}';

/// The built-in unit a stored value refers to, or null for custom text.
DoseUnit? parseUnit(String stored) {
  if (!stored.startsWith(_unitPrefix)) return null;
  final name = stored.substring(1);
  for (final u in DoseUnit.values) {
    if (u.name == name) return u;
  }
  return null;
}

/// Units offered for each form, most likely first.
List<DoseUnit> unitsFor(MedForm form) => switch (form) {
  MedForm.tablet => const [
    DoseUnit.tablet,
    DoseUnit.mg,
    DoseUnit.mcg,
    DoseUnit.iu,
    DoseUnit.g,
  ],
  MedForm.capsule => const [
    DoseUnit.capsule,
    DoseUnit.mg,
    DoseUnit.mcg,
    DoseUnit.iu,
  ],
  MedForm.drops => const [DoseUnit.drop, DoseUnit.ml, DoseUnit.iu],
  MedForm.liquid => const [
    DoseUnit.ml,
    DoseUnit.teaspoon,
    DoseUnit.tablespoon,
    DoseUnit.mg,
  ],
  MedForm.powder => const [
    DoseUnit.sachet,
    DoseUnit.g,
    DoseUnit.scoop,
    DoseUnit.mg,
  ],
  MedForm.injection => const [
    DoseUnit.ml,
    DoseUnit.units,
    DoseUnit.mg,
    DoseUnit.ampoule,
  ],
  MedForm.spray => const [DoseUnit.spray, DoseUnit.dose],
  MedForm.other => const [DoseUnit.piece, DoseUnit.dose, DoseUnit.mg],
};

/// Medication color palette (ARGB). Chosen to stay distinguishable and to
/// read on both light and dark surfaces; always shown next to the name.
const pillColors = <int>[
  0xFFFFFFFF, // white
  0xFFF2E8D5, // cream
  0xFFF6C744, // yellow
  0xFFF39C3D, // orange
  0xFFE5533D, // red
  0xFFE76F9A, // pink
  0xFFB4497E, // magenta
  0xFF8A5CD6, // purple
  0xFF5B6CE0, // indigo
  0xFF3B8FE5, // blue
  0xFF3AB5C9, // cyan
  0xFF2E9E8F, // teal
  0xFF4CAF50, // green
  0xFF9BC53D, // lime
  0xFF8D6E63, // brown
  0xFF9E9E9E, // gray
  0xFF546E7A, // slate
  0xFF263238, // charcoal
];
