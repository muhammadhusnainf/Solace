import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sounds.dart';
import '../theme_provider.dart';

Future<void> showThemeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _ThemeSheet(),
  );
}

class _ThemeSheet extends ConsumerWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    final shade = ref.watch(darkShadeProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final showAccent = !dark || shade.surface == null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _Group(
              label: 'Colors',
              items: accentChoices,
              current: showAccent ? accent : null,
              onPick: (a) => _pickAccent(ref, a),
            ),
            const SizedBox(height: 18),
            _Group(
              label: 'Gradients',
              items: gradientChoices,
              current: showAccent ? accent : null,
              onPick: (a) => _pickAccent(ref, a),
            ),
            const SizedBox(height: 26),
            Text('Dark mode', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final s in darkShades)
                  _ShadeChip(
                    shade: s,
                    accent: accent,
                    selected: s.id == shade.id,
                    onTap: () => _pickShade(ref, s, !dark),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pickAccent(WidgetRef ref, AppAccent a) {
    Sounds.tap();
    ref.read(accentProvider.notifier).set(a);
  }

  void _pickShade(WidgetRef ref, DarkShade s, bool light) {
    Sounds.tap();
    ref.read(darkShadeProvider.notifier).set(s);
    if (light) ref.read(themeProvider.notifier).setDark(true);
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.items,
    required this.current,
    required this.onPick,
  });

  final String label;
  final List<AppAccent> items;
  final AppAccent? current;
  final void Function(AppAccent) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final a in items)
              _Swatch(
                accent: a,
                selected: current != null && a.id == current!.id,
                onTap: () => onPick(a),
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.gradient == null ? accent.seed : null,
          gradient: accent.gradient == null
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: accent.gradient!,
                ),
          border: selected ? Border.all(color: ring, width: 3) : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}

class _ShadeChip extends StatelessWidget {
  const _ShadeChip({
    required this.shade,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final DarkShade shade;
  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview =
        shade.surface ?? Color.lerp(Colors.black, accent.seed, 0.28)!;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: preview,
                border: Border.all(
                  color: selected ? scheme.onSurface : scheme.outlineVariant,
                  width: selected ? 3 : 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 22)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              shade.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
