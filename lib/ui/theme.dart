import 'package:material_ui/material_ui.dart';

/// Design tokens. See design-system/MASTER.md.
abstract final class Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Space below scrolling lists so the FAB never covers the last row.
  static const fabClearance = 96.0;
}

abstract final class Radii {
  static const card = 12.0;
}

const _seed = Color(0xFF2E7D6B);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
  );
  return base.copyWith(
    inputDecorationTheme: const InputDecorationTheme(border: border),
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: Spacing.lg),
      minVerticalPadding: Spacing.sm,
    ),
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Text style for a dose time, e.g. "08:00".
TextStyle? timeStyle(BuildContext context, {bool muted = false}) {
  final theme = Theme.of(context);
  return theme.textTheme.titleMedium?.copyWith(
    fontWeight: FontWeight.w600,
    color: muted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary,
  );
}
