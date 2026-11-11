import 'package:flutter/material.dart';
import '../models.dart';
import 'post_detail_screen.dart';
import 'post_media.dart';

const _ratios = [0.65, 0.8, 1.0, 0.72, 0.9, 1.25, 0.6, 0.85, 1.1];

const _radii = [
  BorderRadius.only(
    topLeft: Radius.circular(22),
    topRight: Radius.circular(22),
    bottomRight: Radius.circular(22),
    bottomLeft: Radius.circular(10),
  ),
  BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(24),
    bottomRight: Radius.circular(12),
    bottomLeft: Radius.circular(24),
  ),
  BorderRadius.only(
    topLeft: Radius.circular(24),
    topRight: Radius.circular(14),
    bottomRight: Radius.circular(24),
    bottomLeft: Radius.circular(24),
  ),
  BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(24),
    bottomRight: Radius.circular(20),
    bottomLeft: Radius.circular(24),
  ),
];

double _ratioFor(int id) => _ratios[(id * 31 + id ~/ 7) % _ratios.length];

BorderRadius _radiusFor(int id) => _radii[id % _radii.length];

class PostWallTile extends StatelessWidget {
  const PostWallTile({super.key, required this.post, this.author});

  final Post post;
  final AppUser? author;

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    final caption = post.description.trim();

    final a = author;
    final full = a == null
        ? post
        : Post(
            id: post.id,
            userId: post.userId,
            description: post.description,
            imageUrl: post.imageUrl,
            resourceType: post.resourceType,
            likes: post.likes,
            authorName: a.fullName.isNotEmpty ? a.fullName : post.authorName,
            authorProfilePicUrl: a.profilePicUrl ?? post.authorProfilePicUrl,
          );

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: full)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: _radiusFor(post.id),
            child: AspectRatio(
              aspectRatio: _ratioFor(post.id),
              child: hasImage
                  ? PostThumb(post: post)
                  : Container(
                      color: scheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        post.description,
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),
          ),
          if (hasImage && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}
