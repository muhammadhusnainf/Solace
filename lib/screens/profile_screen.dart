import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_provider.dart';
import '../friends_provider.dart';
import '../models.dart';
import '../moments_provider.dart';
import '../profile_provider.dart';
import '../widgets/change_profile_photo_dialog.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/image_viewer.dart';
import '../widgets/moments_bar.dart';
import '../widgets/post_detail_screen.dart';
import '../widgets/post_media.dart';
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

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key, required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authProvider.select((s) => s.user?.id));
    final isMe = myId == userId;
    final profile = ref.watch(userProfileProvider(userId));
    final posts = ref.watch(userPostsProvider(userId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userProfileProvider(userId));
        ref.invalidate(userPostsProvider(userId));
        try {
          await Future.wait([
            ref.read(userProfileProvider(userId).future),
            ref.read(userPostsProvider(userId).future),
          ]);
        } catch (_) {
        }
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
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('POSTS',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
          ),
          ..._postsSlivers(context, posts, profile.value),
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
        return [
          SliverPadding(
            padding: const EdgeInsets.all(4),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _PostTile(post: list[i], author: author),
                childCount: list.length,
              ),
            ),
          ),
        ];
      },
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
                  color: group != null && !unseen ? Colors.grey.shade400 : null,
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
                            color: const Color(0xffcbd5e1), width: 2),
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

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.author});
  final Post post;
  final AppUser? author;

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    final fullPost = Post(
      id: post.id,
      userId: post.userId,
      description: post.description,
      imageUrl: post.imageUrl,
      resourceType: post.resourceType,
      likes: post.likes,
      authorName: author?.fullName ?? '',
      authorProfilePicUrl: author?.profilePicUrl,
    );

    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: fullPost)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: hasImage
              ? PostThumb(post: post)
              : Container(
                  color: scheme.surfaceContainerHighest,
                  padding: const EdgeInsets.all(8),
                  child: Text(post.description,
                      maxLines: 5, overflow: TextOverflow.ellipsis),
                ),
        ),
      ),
    );
  }
}