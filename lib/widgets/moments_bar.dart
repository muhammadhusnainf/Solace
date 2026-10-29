import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_provider.dart';
import '../models.dart';
import '../moments_provider.dart';
import '../profile_provider.dart';
import '../screens/moment_viewer_screen.dart';
import 'create_moment_dialog.dart';
import '../cached_image.dart';

const momentRingGradient = LinearGradient(
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
  colors: [Color(0xfff58529), Color(0xffdd2a7b), Color(0xff8134af)],
);

const double _tileWidth = 96;
const double _tileHeight = 148;

class MomentsBar extends ConsumerWidget {
  const MomentsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user;
    if (me == null) return const SizedBox.shrink();

    final groups = ref.watch(momentsProvider).value ?? <MomentGroup>[];
    final seen = ref.watch(seenMomentsProvider);
    final myPic = ref.watch(userProfileProvider(me.id)).value?.profilePicUrl ??
        me.profilePicUrl;

    bool allSeen(MomentGroup g) => g.moments.every((m) => seen.contains(m.id));

    final mine = groups.where((g) => g.userId == me.id).firstOrNull;
    final others = groups.where((g) => g.userId != me.id).toList();

    return SizedBox(
      height: _tileHeight + 20,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: others.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            if (mine == null) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _AddMomentTile(
                  onTap: () => showCreateMomentDialog(context),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _MomentBoxTile(
                imageUrl: mine.moments.last.imageUrl,
                picUrl: myPic,
                label: 'Your moment',
                sublabel: _timeLeft(mine),
                ringColor: Theme.of(context).colorScheme.primary,
                onTap: () => openMoments(context, groups, groups.indexOf(mine)),
                onAdd: () => showCreateMomentDialog(context),
              ),
            );
          }
          final g = others[i - 1];
          final unseen = !allSeen(g);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _MomentBoxTile(
              imageUrl: g.moments.last.imageUrl,
              picUrl: g.profilePicUrl,
              label: g.username.isNotEmpty ? g.username : 'Unknown',
              ringGradient: unseen ? momentRingGradient : null,
              ringColor: unseen ? null : Theme.of(context).colorScheme.outlineVariant,
              onTap: () => openMoments(context, groups, groups.indexOf(g)),
            ),
          );
        },
      ),
    );
  }
}

String _timeLeft(MomentGroup g) {
  final left = g.moments.last.expiresAt.difference(DateTime.now());
  if (left.inMinutes < 1) return 'ending';
  if (left.inHours < 1) return '${left.inMinutes}m left';
  return '${left.inHours}h left';
}

class _AddMomentTile extends StatelessWidget {
  const _AddMomentTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _tileWidth,
        height: _tileHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surfaceContainerLow,
              scheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(Icons.add, color: scheme.primary, size: 24),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Share a moment',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentBoxTile extends StatelessWidget {
  const _MomentBoxTile({
    required this.imageUrl,
    required this.picUrl,
    required this.label,
    required this.onTap,
    this.sublabel,
    this.ringGradient,
    this.ringColor,
    this.onAdd,
  });

  final String imageUrl;
  final String? picUrl;
  final String label;
  final String? sublabel;
  final Gradient? ringGradient;
  final Color? ringColor;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPic = picUrl != null && picUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _tileWidth,
        height: _tileHeight,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: ringGradient,
          color: ringGradient == null ? ringColor : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: cachedImage(imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: scheme.surfaceContainerHighest),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0, 0.55],
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundImage: hasPic ? cachedImage(picUrl!) : null,
                    child: hasPic ? null : const Icon(Icons.person, size: 14),
                  ),
                ),
              ),
              if (onAdd != null)
                Positioned(
                  right: 6,
                  top: 6,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (sublabel != null)
                      Text(
                        sublabel!,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
