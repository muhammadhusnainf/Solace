import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_provider.dart';
import '../feed_provider.dart';
import '../friends_provider.dart';
import '../likes_provider.dart';
import '../moments_provider.dart';
import '../widgets/create_moment_dialog.dart';
import '../widgets/create_post_dialog.dart';
import '../widgets/moments_bar.dart';
import '../widgets/post_card.dart';
import 'explore_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: PopupMenuButton(
          offset: const Offset(0, 20),
          icon: const Icon(Icons.add_box_outlined, size: 30),
          itemBuilder: (context) => [
            const PopupMenuItem(child: Text('Post'), value: 'post'),
            const PopupMenuItem(child: Text('Moment'), value: 'moment'),
            const PopupMenuItem(child: Text('AI'), value: 'ai'),
          ],
          onSelected: (value) {
            if (value == 'post') showCreatePostDialog(context);
            if (value == 'moment') showCreateMomentDialog(context);
          },
        ),
        actions: [
          GestureDetector(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: 76,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xffe2e8f0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          FocusScope.of(context).unfocus();
          setState(() => _selectedIndex = index);
          if (index == 3) {
            ref.invalidate(myFriendsProvider);
            ref.invalidate(incomingRequestsProvider);
          }
        },
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.group), label: 'My Friends'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _FeedTab(),
          SearchScreen(),
          ExploreScreen(),
          FriendsScreen(),
          _ProfileTab(),
        ],
      ),
    );
  }
}

class _FeedTab extends ConsumerWidget {
  const _FeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(feedProvider);
        ref.invalidate(momentsProvider);
        await Future.wait([
          ref.read(feedProvider.future),
          ref.read(momentsProvider.future),
          ref.read(likesProvider.notifier).refresh(),
        ]);
      },
      child: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load feed: $err')),
        data: (posts) {
          return ListView.separated(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: posts.isEmpty ? 2 : posts.length + 1,
            separatorBuilder: (context, i) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              if (i == 0) return const MomentsBar();
              if (posts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: Text('No posts yet.')),
                );
              }
              return PostCard(post: posts[i - 1], interactive: true);
            },
          );
        },
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider.select((s) => s.user?.id));
    if (userId == null) return const SizedBox.shrink();
    return ProfileView(userId: userId);
  }
}