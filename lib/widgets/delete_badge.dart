import 'package:flutter/material.dart';

class DeleteBadge extends StatelessWidget {
  const DeleteBadge({super.key, required this.onTap, this.size = 32});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surface.withValues(alpha: 0.92),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Icon(Icons.delete_rounded, size: size * 0.56, color: scheme.error),
      ),
    );
  }
}
