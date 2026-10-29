import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../feed_provider.dart';
import '../likes_provider.dart';
import '../models.dart';
import '../refresh_utils.dart';
import '../search_provider.dart';
import '../widgets/highlight_text.dart';
import '../widgets/offline_notice.dart';
import '../widgets/post_card.dart';
import '../widgets/post_detail_screen.dart';
import '../widgets/post_media.dart';
import 'profile_screen.dart';
import '../cached_image.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _run(text));
  }

  void _run(String text) {
    _debounce?.cancel();
    final term = text.trim();
    if (term != _query) setState(() => _query = term);
  }

  void _clear() {
    _controller.clear();
    _run('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _run,
            decoration: InputDecoration(
              hintText: 'Search posts and people',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.close), onPressed: _clear),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Expanded(child: _query.isEmpty ? _wall() : _results()),
      ],
    );
  }

  Widget _wall() {
    final feed = ref.watch(feedProvider);
    final posts = feed.value;
    final scheme = Theme.of(context).colorScheme;

    Future<void> refresh() async {
      ref.invalidate(feedProvider);
      await Future.wait([
        settle(ref.read(feedProvider.future)),
        settle(ref.read(likesProvider.notifier).refresh()),
      ]);
    }

    Widget content() {
      if (posts == null) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            if (feed.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              OfflineNotice(onRetry: refresh),
          ],
        );
      }
      if (posts.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(child: Text('Nothing to explore yet.')),
          ],
        );
      }
      final width = MediaQuery.of(context).size.width;
      final columns = width >= 1024 ? 4 : (width >= 640 ? 3 : 2);

      return NotificationListener<ScrollStartNotification>(
        onNotification: (_) {
          FocusScope.of(context).unfocus();
          return false;
        },
        child: MasonryGridView.count(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          itemCount: posts.length,
          itemBuilder: (context, i) => _ExploreTile(post: posts[i]),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              const Text(
                'Explore posts',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                'Made for you to discover',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(onRefresh: refresh, child: content()),
        ),
      ],
    );
  }

  Widget _results() {
    final results = ref.watch(searchProvider(_query));

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Search failed: $err')),
      data: (data) {
        if (data.isEmpty) {
          return Center(child: Text('No results for "$_query".'));
        }
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (data.users.isNotEmpty) ...[
              const _SectionHeader('People'),
              for (final u in data.users) _UserTile(user: u, query: _query),
            ],
            if (data.posts.isNotEmpty) ...[
              const _SectionHeader('Posts'),
              for (final p in data.posts) ...[
                PostCard(post: p, interactive: true, highlight: _query),
                const SizedBox(height: 16),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.query});

  final AppUser user;
  final String query;

  @override
  Widget build(BuildContext context) {
    final hasPic = user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: hasPic ? cachedImage(user.profilePicUrl!) : null,
        child: hasPic ? null : const Icon(Icons.person),
      ),
      title: HighlightText(
        user.fullName.isNotEmpty ? user.fullName : user.username,
        query: query,
      ),
      subtitle: HighlightText('@${user.username}', query: query),
      onTap: () => openProfile(context, user.id),
    );
  }
}

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

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    final caption = post.description.trim();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
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
