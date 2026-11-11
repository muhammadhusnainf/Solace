import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../api_client.dart';
import '../auth_provider.dart';
import '../friends_provider.dart';
import '../models.dart';
import '../moments_provider.dart';
import '../profile_provider.dart';
import '../scenes_provider.dart';
import '../widgets/change_profile_photo_dialog.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/delete_badge.dart';
import '../widgets/image_viewer.dart';
import '../widgets/moments_bar.dart';
import '../widgets/post_media.dart';
import '../widgets/post_wall_tile.dart';
import 'chat_screen.dart';
import 'moment_viewer_screen.dart';
import '../cached_image.dart';

Future<void> openProfile(BuildContext context, int userId) {
  final container = ProviderScope.containerOf(context);
  container.invalidate(myFriendsProvider);
  container.invalidate(friendStatusProvider(userId));
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(),
      body: ProfileView(userId: userId),
    ),
  ));
}

Future<void> confirmCancelRequest(
    BuildContext context, WidgetRef ref, AppUser user) async {
  final messenger = ScaffoldMessenger.of(context);
  final name = user.fullName.isNotEmpty ? user.fullName : user.username;
  final ok = await showConfirmDialog(
    context,
    title: 'Cancel request',
    message: 'Cancel your friend request to $name?',
    confirmLabel: 'Cancel request',
    cancelLabel: 'Keep',
    destructive: true,
  );
  if (!ok) return;
  try {
    await ref.read(requestedProvider.notifier).cancelRequest(user.id);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not cancel request: $e')),
    );
  }
}

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key, required this.userId});
  final int userId;

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final myId = ref.watch(authProvider.select((s) => s.user?.id));
    final isMe = myId == userId;
    final profile = ref.watch(userProfileProvider(userId));
    final posts = ref.watch(userPostsProvider(userId));
    final scenes = _tab == 1 ? ref.watch(userScenesProvider(userId)) : null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userProfileProvider(userId));
        ref.invalidate(userPostsProvider(userId));
        ref.invalidate(userScenesProvider(userId));
        try {
          await Future.wait([
            ref.read(userProfileProvider(userId).future),
            ref.read(userPostsProvider(userId).future),
            if (_tab == 1) ref.read(userScenesProvider(userId).future),
          ]);
        } catch (_) {}
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: profile.when(
              loading: () => const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator())),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('Failed to load profile: $err')),
              ),
              data: (user) => _Header(user: user, isMe: isMe),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: _ProfileTabs(
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
          ),
          if (scenes == null)
            ..._postsSlivers(context, posts, profile.value)
          else
            ..._sceneSlivers(scenes, isMe),
        ],
      ),
    );
  }

  List<Widget> _postsSlivers(
      BuildContext context, AsyncValue<List<Post>> posts, AppUser? author) {
    return posts.when(
      loading: () => const [
        SliverToBoxAdapter(
            child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()))),
      ],
      error: (err, _) => [
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('Failed to load posts: $err')))),
      ],
      data: (list) {
        if (list.isEmpty) {
          return const [
            SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No posts yet.')))),
          ];
        }
        final width = MediaQuery.of(context).size.width;
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: width >= 640 ? 3 : 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childCount: list.length,
              itemBuilder: (context, i) =>
                  PostWallTile(post: list[i], author: author),
            ),
          ),
        ];
      },
    );
  }

  List<Widget> _sceneSlivers(AsyncValue<List<Scene>> scenes, bool isMe) {
    return scenes.when(
      loading: () => const [
        SliverToBoxAdapter(
            child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()))),
      ],
      error: (err, _) => [
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('Failed to load scenes: $err')))),
      ],
      data: (list) {
        if (list.isEmpty) {
          return const [
            SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No scenes yet.')))),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _SceneTile(scene: list[i], isMe: isMe),
                childCount: list.length,
              ),
            ),
          ),
        ];
      },
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget tab(IconData icon, String label, int i) {
      final on = index == i;
      final color = on ? scheme.primary : scheme.onSurfaceVariant;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: on ? scheme.primary : scheme.outlineVariant,
                  width: on ? 2.5 : 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(Icons.grid_view_rounded, 'Posts', 0),
        tab(Icons.play_circle_outline, 'Scenes', 1),
      ],
    );
  }
}

class _SceneTile extends ConsumerWidget {
  const _SceneTile({required this.scene, required this.isMe});

  final Scene scene;
  final bool isMe;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Delete scene',
      message: 'This scene will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.deleteScene(scene.id);
      ref.invalidate(userScenesProvider(scene.userId));
      ref.invalidate(scenesProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Scene deleted')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not delete scene: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _ScenePreview(scene: scene)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: cachedImage(
                scene.thumbnailUrl ?? videoPosterUrl(scene.videoUrl),
              ),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: scheme.surfaceContainerHighest),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: [0, 0.5],
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${scene.likesCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isMe)
              Positioned(
                top: 6,
                right: 6,
                child: DeleteBadge(
                  size: 30,
                  onTap: () => _delete(context, ref),
                ),
              )
            else
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScenePreview extends StatelessWidget {
  const _ScenePreview({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const Border(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: UrlVideo(url: scene.videoUrl))),
            if (scene.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  scene.caption,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.user, required this.isMe});
  final AppUser user;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPic =
        user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty;

    final status = ref.watch(friendStateProvider(user.id));

    final groups = ref.watch(momentsProvider).maybeWhen(
          data: (g) => g,
          orElse: () => <MomentGroup>[],
        );
    final seen = ref.watch(seenMomentsProvider);
    final group =
        isMe ? null : groups.where((g) => g.userId == user.id).firstOrNull;
    final unseen =
        group != null && !group.moments.every((m) => seen.contains(m.id));

    void onAvatarTap() {
      if (isMe) {
        showChangeProfilePhotoDialog(context);
      } else if (group != null) {
        openMoments(context, [group], 0);
      } else if (hasPic) {
        openImageViewer(context, user.profilePicUrl!);
      }
    }

    Future<void> sendRequest() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(requestedProvider.notifier).follow(user.id);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not send request: $e')),
        );
      }
    }

    Future<void> answerRequest({required bool accept}) async {
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(requestedProvider.notifier);
      try {
        if (accept) {
          await notifier.acceptRequest(user.id);
        } else {
          await notifier.rejectRequest(user.id);
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
              content: Text(
                  'Could not ${accept ? 'accept' : 'reject'} the request: $e')),
        );
      }
    }

    Future<void> removeFriend() async {
      final messenger = ScaffoldMessenger.of(context);
      final name = user.fullName.isNotEmpty ? user.fullName : user.username;
      final ok = await showConfirmDialog(
        context,
        title: 'Remove friend',
        message: 'Remove $name from your friends?',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!ok) return;
      try {
        await ref.read(requestedProvider.notifier).unfriend(user.id);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not remove friend: $e')),
        );
      }
    }

    return Column(
      children: [
        const SizedBox(height: 40),
        GestureDetector(
          onTap: onAvatarTap,
          onLongPress: !isMe && hasPic
              ? () => openImageViewer(context, user.profilePicUrl!)
              : null,
          child: Stack(
            children: [
              Container(
                padding: EdgeInsets.all(group != null ? 3 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unseen ? momentRingGradient : null,
                  color: group != null && !unseen
                      ? Theme.of(context).colorScheme.outlineVariant
                      : null,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: group != null
                        ? Theme.of(context).colorScheme.surface
                        : null,
                    border: group != null
                        ? null
                        : Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 56,
                    backgroundImage:
                        hasPic ? cachedImage(user.profilePicUrl!) : null,
                    onBackgroundImageError: hasPic ? (_, _) {} : null,
                    child: hasPic ? null : const Icon(Icons.person, size: 48),
                  ),
                ),
              ),
              if (isMe)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(user.fullName.isNotEmpty ? user.fullName : user.username,
            style: const TextStyle(fontSize: 18)),
        if (!isMe) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ...switch (status) {
                FriendStatus.friends => [
                    _GreyButton(
                        label: 'Message',
                        onPressed: () => openChat(context, user)),
                    _GreyButton(label: 'Remove', onPressed: removeFriend),
                  ],
                FriendStatus.requested => [
                    _GreyButton(
                        label: 'Requested',
                        onPressed: () =>
                            confirmCancelRequest(context, ref, user)),
                  ],
                FriendStatus.incoming => [
                    _GreyButton(
                        label: 'Accept',
                        onPressed: () => answerRequest(accept: true)),
                    _GreyButton(
                        label: 'Reject',
                        onPressed: () => answerRequest(accept: false)),
                  ],
                FriendStatus.none => [
                    _GreyButton(label: 'Follow', onPressed: sendRequest),
                  ],
                null => [
                    const _GreyButton(label: 'Follow', onPressed: null),
                  ],
              },
            ],
          ),
        ],
        const SizedBox(height: 32),
        const Divider(height: 1),
      ],
    );
  }
}

class _GreyButton extends StatelessWidget {
  const _GreyButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        disabledBackgroundColor:
            Theme.of(context).colorScheme.surfaceContainerHighest,
        disabledForegroundColor:
            Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}
