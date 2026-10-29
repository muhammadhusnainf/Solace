import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_provider.dart';
import '../feed_provider.dart';
import '../friends_provider.dart';
import '../likes_provider.dart';
import '../moments_provider.dart';
import '../refresh_utils.dart';
import '../sounds.dart';
import '../theme_provider.dart';
import '../widgets/create_moment_dialog.dart';
import '../widgets/create_post_dialog.dart';
import '../widgets/moments_bar.dart';
import '../widgets/offline_notice.dart';
import '../widgets/post_card.dart';
import '../widgets/theme_sheet.dart';
import 'explore_screen.dart';
import 'friends_screen.dart';
import 'journeys_screen.dart';
import 'profile_screen.dart';
import 'scenes_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  int _selectedIndex = 0;

  void _openFriends() {
    ref.invalidate(myFriendsProvider);
    ref.invalidate(incomingRequestsProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Friends')),
          body: const FriendsScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final soft =
        softGradient(ref.watch(accentProvider), Theme.of(context).brightness);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _selectedIndex == 2
          ? null
          : AppBar(
              backgroundColor: soft == null ? null : Colors.transparent,
              scrolledUnderElevation: soft == null ? null : 0,
              flexibleSpace: soft == null
                  ? null
                  : DecoratedBox(decoration: BoxDecoration(gradient: soft)),
              leading: PopupMenuButton<String>(
                offset: const Offset(0, 20),
                icon: const Icon(Icons.add_box_outlined, size: 30),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'post', child: Text('Post')),
                  const PopupMenuItem(value: 'moment', child: Text('Moment')),
                  const PopupMenuItem(value: 'ai', child: Text('AI')),
                ],
                onSelected: (value) {
                  if (value == 'post') showCreatePostDialog(context);
                  if (value == 'moment') showCreateMomentDialog(context);
                },
              ),
              actions: [
                IconButton(
                  tooltip: 'Friends',
                  icon: const Icon(Icons.group_outlined),
                  onPressed: _openFriends,
                ),
                GestureDetector(
                  onLongPress: () {
                    Sounds.tap();
                    showThemeSheet(context);
                  },
                  child: IconButton(
                    icon: Icon(isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined),
                    onPressed: () =>
                        ref.read(themeProvider.notifier).setDark(!isDark),
                  ),
                ),
                GestureDetector(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      width: 76,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Logout",
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  onTap: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(gradient: soft),
        child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          FocusScope.of(context).unfocus();
          setState(() => _selectedIndex = index);
        },
        backgroundColor: soft == null ? scheme.surface : Colors.transparent,
        elevation: soft == null ? null : 0,
        indicatorColor: scheme.primaryContainer,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.play_circle), label: 'Scenes'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Journeys'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const _FeedTab(),
          const ExploreScreen(),
          ScenesScreen(active: _selectedIndex == 2),
          const JourneysScreen(),
          const _ProfileTab(),
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
    final posts = feed.value;

    Future<void> refresh() async {
      ref.invalidate(feedProvider);
      ref.invalidate(momentsProvider);
      await Future.wait([
        settle(ref.read(feedProvider.future)),
        settle(ref.read(momentsProvider.future)),
        settle(ref.read(likesProvider.notifier).refresh()),
      ]);
      if (context.mounted && ref.read(feedProvider).hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Can't refresh right now")),
        );
      }
    }

    Widget content() {
      if (posts == null) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
            if (feed.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              OfflineNotice(onRetry: refresh),
          ],
        );
      }
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
    }

    return RefreshIndicator(onRefresh: refresh, child: content());
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