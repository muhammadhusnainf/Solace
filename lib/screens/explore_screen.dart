import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feed_provider.dart';
import '../likes_provider.dart';
import '../models.dart';
import '../widgets/post_media.dart';
import '../widgets/post_detail_screen.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(feedProvider);
        await Future.wait([
          ref.read(feedProvider.future),
          ref.read(likesProvider.notifier).refresh(),
        ]);
      },
      child: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load posts: $err')),
        data: (posts) {
          if (posts.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 200),
                Center(child: Text('Nothing to explore yet.')),
              ],
            );
          }
          final width = MediaQuery.of(context).size.width;
          final columns = width >= 1024 ? 4 : (width >= 640 ? 3 : 2);
          final tileHeight = width >= 640 ? 224.0 : 160.0;

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: tileHeight,
            ),
            itemCount: posts.length,
            itemBuilder: (context, i) => _ExploreTile(post: posts[i]),
          );
        },
      ),
    );
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: hasImage
          ? PostThumb(post: post)
          : Container(
              color: scheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(8),
              child: Text(
                post.description,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ),
    );
  }
}