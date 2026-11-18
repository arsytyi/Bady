# Bady design system

Source of truth for how Bady looks. Code tokens live in `lib/ui/theme.dart`; screens use `Theme.of(context)` and these tokens, never raw hex values. Rules follow the UI UX Pro Max checklist.

## Direction

Calm, clinical but friendly health utility. Material 3, flat surfaces with tonal layers, no decorative effects. The most important information on every screen is "what to take and when", so time and dose get the strongest type.

## Color

Seed: teal `#2E7D6B` (trust, health, not alarming). Material 3 generates the full light and dark schemes from it; dark mode uses the tonal dark scheme, not inverted colors.

| Role | Use |
|---|---|
| primary / onPrimary | Main action per screen (FAB, Save), upcoming dose times |
| surface / onSurface | Screen background and main text |
| onSurfaceVariant | Secondary text (subtitles, hints) – still ≥4.5:1 |
| outline | Past/inactive state, always paired with a text label |
| error / errorContainer | Validation problems, destructive actions |

Medication colors (`medColors`) are user-chosen identification colors. They are always shown together with the medication's name, never as the only signal.

## Typography

System font (Roboto on Android) with Material 3 type roles:

- Dose times: `titleLarge`/`titleMedium`, weight 600, tabular figures.
- Section headers: `titleSmall` in primary.
- Body: `bodyLarge` 16sp, list subtitles `bodyMedium`.
- Supports system font scaling; text wraps instead of truncating where it carries meaning.

## Spacing and shape

- 4/8dp rhythm: 4, 8, 12, 16, 24, 32. Screen gutter 16dp. Section gap 24dp.
- Corner radius: 12dp for cards and inputs, full for avatars and chips.
- Lists leave 96dp bottom inset so the FAB never covers the last row.

## Interaction

- Touch targets ≥48dp; icon-only buttons always have a tooltip (accessible name).
- One primary action per screen (FAB or Save). Delete lives in an overflow menu or app bar, in error color, and always asks for confirmation.
- Material ripple for press feedback. Default Material motion; no custom animations yet.
- Forms: visible labels, required fields marked with *, errors shown next to the problem with a clear fix.

## Navigation

Bottom navigation bar with three top-level destinations (Today, Medications, Settings), icon + label, active state highlighted. Detail screens push on top with a standard back arrow.
