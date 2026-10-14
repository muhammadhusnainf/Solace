import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_provider.dart';
import '../comments_provider.dart';
import '../likes_provider.dart';
import '../models.dart';
import '../profile_provider.dart';
import '../screens/profile_screen.dart';
import 'comment_sheet.dart';
import 'post_detail_screen.dart';
import 'post_media.dart';

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, this.interactive = false});

  final Post post;

  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final likes = ref.watch(likesProvider);
    final isLiked = likes.isLiked(post.id);
    final likeCount = likes.displayLikes(post.id, post.likes);

    void openPost() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
    void openAuthor() => openProfile(context, post.userId);

    final commentCount = !interactive
        ? 0
        : ref.watch(commentsProvider(post.id)).maybeWhen(
              data: (list) => list.length,
              orElse: () => 0,
            );

    final hasAvatar = post.authorProfilePicUrl != null &&
        post.authorProfilePicUrl!.isNotEmpty;

    Future<void> toggleLike() async {
      try {
        await ref.read(likesProvider.notifier).toggle(post.id, likeCount);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update like: $e')),
          );
        }
      }
    }

    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openAuthor,
                child: CircleAvatar(
                  backgroundImage: hasAvatar
                      ? NetworkImage(post.authorProfilePicUrl!)
                      : null,
                  child: hasAvatar ? null : const Icon(Icons.person),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: openAuthor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      post.authorName.isNotEmpty ? post.authorName : 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
          post.isVideo
              ? PostMedia(post: post)
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () {
                    if (user != null && !isLiked) toggleLike();
                  },
                  child: PostMedia(post: post),
                ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            children: [
              IconButton(
                icon: isLiked
                    ? const Icon(Icons.favorite, color: Colors.red)
                    : const Icon(Icons.favorite_border),
                onPressed: user == null ? null : toggleLike,
              ),
              Text('$likeCount ${likeCount == 1 ? 'like' : 'likes'}'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(post.description),
        ),
        if (commentCount > 0)
          InkWell(
            onTap: openPost,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
              child: Text(
                commentCount == 1
                    ? 'View 1 comment'
                    : 'View all $commentCount comments',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
        if (interactive)
          _AddCommentPrompt(
            onTap: () => showCommentSheet(context, post.id),
          ),
      ],
    );

    if (!interactive) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: openPost,
      child: card,
    );
  }
}

class _AddCommentPrompt extends ConsumerWidget {
  const _AddCommentPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user;
    if (me == null) return const SizedBox.shrink();

    final avatarUrl = ref.watch(userProfileProvider(me.id)).maybeWhen(
          data: (u) => u.profilePicUrl,
          orElse: () => me.profilePicUrl,
        );
    final hasPic = avatarUrl != null && avatarUrl.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundImage: hasPic ? NetworkImage(avatarUrl) : null,
              onBackgroundImageError: hasPic ? (_, __) {} : null,
              child: hasPic ? null : const Icon(Icons.person, size: 15),
            ),
            const SizedBox(width: 10),
            Text(
              'Add a comment...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}