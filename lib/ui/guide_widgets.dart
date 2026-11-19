import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import '../domain/interactions.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/files.dart';
import 'pill_icon.dart';
import 'theme.dart';
import 'widgets.dart';

String _lang(AppLocalizations l) => l.localeName.split('_').first;

/// Reference notes for the substances in [medication]; nothing when the
/// catalog has none.
class GuideSection extends ConsumerWidget {
  const GuideSection({super.key, required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final catalog = ref.watch(interactionCatalogProvider).value;
    if (catalog == null) return const SizedBox.shrink();
    final m = medication;
    final keys = m.ingredients == null
        ? catalog.detect(m.name)
        : m.ingredientKeys;
    final substances = [
      for (final k in keys)
        if (catalog.substance(k) case final s? when s.info != null) s,
    ];
    final product = catalog.products
        .where((p) => p.fullName == m.name)
        .firstOrNull;
    if (substances.isEmpty && product?.url == null) {
      return const SizedBox.shrink();
    }
    final lang = _lang(l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l.guideTitle),
        for (final s in substances)
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(s.name(lang)),
            subtitle: Text(
              s.info!.intakeIn(lang),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showSubstanceGuide(context, s),
          ),
        if (product?.url case final url?)
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(l.guideProductPage),
            subtitle: Text(product!.amountIn(lang)),
            onTap: () => DeviceFiles.openUrl(url),
          ),
      ],
    );
  }
}

/// How to take [substance], cautions and sources.
Future<void> showSubstanceGuide(BuildContext context, Substance substance) {
  final l = AppLocalizations.of(context);
  final lang = _lang(l);
  final info = substance.info!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      Widget heading(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: Spacing.sm),
            Text(text, style: theme.textTheme.titleSmall),
          ],
        ),
      );
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.xl,
          ),
          children: [
            Text(substance.name(lang), style: theme.textTheme.headlineSmall),
            heading(Icons.schedule, l.guideIntake),
            Text(info.intakeIn(lang), style: theme.textTheme.bodyLarge),
            heading(Icons.warning_amber_rounded, l.guideCautions),
            Text(info.cautionsIn(lang), style: theme.textTheme.bodyLarge),
            heading(Icons.link, l.guideSources),
            for (final s in info.sources)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.name),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => DeviceFiles.openUrl(s.url),
              ),
            const SizedBox(height: Spacing.md),
            Text(
              l.compatDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// One suggestion in the name field's list.
class ProductOption extends StatelessWidget {
  const ProductOption({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: PillIcon(
        shape: product.shape,
        color: Color(product.color),
        color2: product.color2 == null ? null : Color(product.color2!),
        size: 36,
      ),
      title: Text(product.name),
      subtitle: Text('${product.brand} · ${product.amountIn(_lang(l))}'),
      onTap: onTap,
    );
  }
}

/// Every substance the catalog has notes for.
class GuideListScreen extends ConsumerWidget {
  const GuideListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = _lang(l);
    final catalog = ref.watch(interactionCatalogProvider).value;
    final substances = [
      for (final s in catalog?.substances ?? const <Substance>[])
        if (s.info != null) s,
    ]..sort((a, b) => a.name(lang).compareTo(b.name(lang)));
    return Scaffold(
      appBar: AppBar(title: Text(l.guideAll)),
      body: ListView(
        children: [
          for (final s in substances)
            ListTile(
              title: Text(s.name(lang)),
              subtitle: Text(
                s.info!.intakeIn(lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showSubstanceGuide(context, s),
            ),
        ],
      ),
    );
  }
}
