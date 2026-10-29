import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sounds.dart';
import '../theme_provider.dart';

Future<void> showThemeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _ThemeSheet(),
  );
}

class _ThemeSheet extends ConsumerWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tints light mode. Dark mode stays the same',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 18),
            _Group(
              label: 'Colors',
              items: accentChoices,
              current: accent,
              onPick: (a) => _pick(ref, a),
            ),
            const SizedBox(height: 18),
            _Group(
              label: 'Gradients',
              items: gradientChoices,
              current: accent,
              onPick: (a) => _pick(ref, a),
            ),
          ],
        ),
      ),
    );
  }

  void _pick(WidgetRef ref, AppAccent a) {
    Sounds.tap();
    ref.read(accentProvider.notifier).set(a);
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
  final AppAccent current;
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
                selected: a.id == current.id,
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
