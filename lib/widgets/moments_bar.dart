import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_provider.dart';
import '../models.dart';
import '../moments_provider.dart';
import '../screens/moment_viewer_screen.dart';
import 'create_moment_dialog.dart';

const momentRingGradient = LinearGradient(
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
  colors: [Color(0xfff58529), Color(0xffdd2a7b), Color(0xff8134af)],
);

class MomentsBar extends ConsumerWidget {
  const MomentsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user;
    if (me == null) return const SizedBox.shrink();

    final groups = ref.watch(momentsProvider).maybeWhen(
          data: (g) => g,
          orElse: () => <MomentGroup>[],
        );
    final seen = ref.watch(seenMomentsProvider);

    bool allSeen(MomentGroup g) => g.moments.every((m) => seen.contains(m.id));

    final mine = groups.where((g) => g.userId == me.id).firstOrNull;
    final others = groups.where((g) => g.userId != me.id).toList();

    return SizedBox(
      height: 124,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: others.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _MomentBubble(
              label: mine == null ? 'Add moment' : 'Your moment',
              sublabel: mine == null ? null : _timeLeft(mine),
              picUrl: me.profilePicUrl,
              hasMoments: mine != null,
              seen: false,
              isMine: true,
              onAdd: () => showCreateMomentDialog(context),
              onTap: () {
                if (mine == null) {
                  showCreateMomentDialog(context);
                } else {
                  openMoments(context, groups, groups.indexOf(mine));
                }
              },
            );
          }
          final g = others[i - 1];
          return _MomentBubble(
            label: g.username.isNotEmpty ? g.username : 'Unknown',
            picUrl: g.profilePicUrl,
            hasMoments: true,
            seen: allSeen(g),
            onTap: () => openMoments(context, groups, groups.indexOf(g)),
          );
        },
      ),
    );
  }
}

// time left before the newest moment disappears
String _timeLeft(MomentGroup g) {
  final left = g.moments.last.expiresAt.difference(DateTime.now());
  if (left.inMinutes < 1) return 'ending';
  if (left.inHours < 1) return '${left.inMinutes}m left';
  return '${left.inHours}h left';
}

class _MomentBubble extends StatelessWidget {
  const _MomentBubble({
    required this.label,
    required this.picUrl,
    required this.hasMoments,
    required this.seen,
    required this.onTap,
    this.isMine = false,
    this.sublabel,
    this.onAdd,
  });

  final String label;
  final String? picUrl;
  final bool hasMoments;
  final bool seen;
  final bool isMine;
  final String? sublabel;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final hasPic = picUrl != null && picUrl!.isNotEmpty;
    final unseen = !isMine && hasMoments && !seen;

    // my own ring is solid blue so it never looks like someone elses unseen one
    Color? ringColor;
    if (isMine && hasMoments) ringColor = Colors.blue;
    if (!isMine && hasMoments && seen) ringColor = Colors.grey.shade400;

    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: unseen ? momentRingGradient : null,
                    color: ringColor,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: surface),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: hasPic ? NetworkImage(picUrl!) : null,
                      child: hasPic ? null : const Icon(Icons.person),
                    ),
                  ),
                ),
              ),
              if (isMine)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                        border: Border.all(color: surface, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          if (sublabel != null)
            Text(
              sublabel!,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}