import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_provider.dart';
import '../friends_provider.dart';
import '../models.dart';
import '../profile_provider.dart';
import '../search_provider.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import '../cached_image.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          TabBar(
            tabs: [
              Tab(text: 'Chats'),
              Tab(child: _RequestsLabel()),
              Tab(text: 'Discover'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ChatsTab(),
                _RequestsTab(),
                _DiscoverTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsLabel extends ConsumerWidget {
  const _RequestsLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(incomingRequestsProvider).value?.length ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Requests'),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.user, {this.radius = 24});
  final AppUser? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = user?.profilePicUrl;
    final hasPic = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundImage: hasPic ? cachedImage(url) : null,
      onBackgroundImageError: hasPic ? (_, _) {} : null,
      child: hasPic ? null : const Icon(Icons.person),
    );
  }
}

String _nameOf(AppUser u) => u.fullName.isNotEmpty ? u.fullName : u.username;

class _ChatsTab extends ConsumerWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(myFriendsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myFriendsProvider);
        try {
          await ref.read(myFriendsProvider.future);
        } catch (_) {
        }
      },
      child: friends.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (err, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('Failed to load friends: $err')),
            ),
          ],
        ),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(32),
              children: [
                const SizedBox(height: 48),
                const Icon(Icons.chat_bubble_outline,
                    size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No friends to chat with yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                    'Accept a request or follow someone to start chatting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => DefaultTabController.of(context).animateTo(2),
                    child: const Text('Find people'),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final u = list[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: _Avatar(u),
                title: Text(_nameOf(u)),
                subtitle: Text('@${u.username}'),
                trailing: const Icon(Icons.chat_bubble_outline, size: 20),
                onTap: () => openChat(context, u),
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider);
    final sent = ref.watch(pendingSentIdsProvider);
    final loadingFirst = incoming.isLoading && !incoming.hasValue;
    final nothing = incoming.hasValue && incoming.value!.isEmpty && sent.isEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myFriendsProvider);
        ref.invalidate(incomingRequestsProvider);
        try {
          await ref.read(incomingRequestsProvider.future);
        } catch (_) {
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (loadingFirst)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          const _Requests(),
          const _SentRequests(),
          if (nothing)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: Text('No friend requests right now.',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Requests extends ConsumerWidget {
  const _Requests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingRequestsProvider);

    return requests.when(
      loading: () => const SizedBox.shrink(),
      error: (err, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Text('Could not load friend requests: $err'),
      ),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Friend requests (${list.length})',
                  style:
                      const TextStyle(color: Color(0xff64748b), fontSize: 15)),
            ),
            for (final u in list) _RequestTile(key: ValueKey(u.id), user: u),
            const Divider(height: 24),
          ],
        );
      },
    );
  }
}

class _RequestTile extends ConsumerStatefulWidget {
  const _RequestTile({super.key, required this.user});
  final AppUser user;

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String failMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$failMsg: $e')));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final notifier = ref.read(requestedProvider.notifier);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () => openProfile(context, user.id),
      leading: _Avatar(user),
      title: Text(_nameOf(user)),
      trailing: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Accept',
                  icon: const Icon(Icons.check_circle_outline),
                  color: Colors.green,
                  onPressed: () => _run(
                      () => notifier.acceptRequest(user.id),
                      'Could not accept'),
                ),
                IconButton(
                  tooltip: 'Reject',
                  icon: const Icon(Icons.cancel_outlined),
                  color: Colors.red,
                  onPressed: () => _run(
                      () => notifier.rejectRequest(user.id),
                      'Could not reject'),
                ),
              ],
            ),
    );
  }
}

class _SentRequests extends ConsumerWidget {
  const _SentRequests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSentIdsProvider);
    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Requests you sent (${pending.length})',
              style: const TextStyle(color: Color(0xff64748b), fontSize: 15)),
        ),
        for (final id in pending) _SentTile(key: ValueKey(id), userId: id),
      ],
    );
  }
}

class _SentTile extends ConsumerWidget {
  const _SentTile({super.key, required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider(userId)).value;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () => openProfile(context, userId),
      leading: _Avatar(user),
      title: Text(user == null ? '...' : _nameOf(user)),
      trailing: user == null
          ? null
          : TextButton(
              onPressed: () => confirmCancelRequest(context, ref, user),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
            ),
    );
  }
}

class _DiscoverTab extends ConsumerStatefulWidget {
  const _DiscoverTab();

  @override
  ConsumerState<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<_DiscoverTab>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  Timer? _debounce;

  String _query = '';

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _run,
            decoration: InputDecoration(
              hintText: 'Search for people',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close), onPressed: _clear),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _query.isEmpty ? const _Suggestions() : _People(term: _query),
        ),
      ],
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(suggestionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(suggestionsProvider);
        ref.invalidate(myFriendsProvider);
        try {
          await ref.read(suggestionsProvider.future);
        } catch (_) {
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Suggested for you',
                style: TextStyle(color: Color(0xff64748b), fontSize: 15)),
          ),
          suggestions.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('Failed to load suggestions: $err')),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No suggestions right now.')),
                );
              }
              return Column(
                children: [
                  for (final u in list) _PersonTile(user: u),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _People extends ConsumerWidget {
  const _People({required this.term});
  final String term;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authProvider.select((s) => s.user?.id));
    final results = ref.watch(searchProvider(term));

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Search failed: $err')),
      data: (data) {
        final people = data.users.where((u) => u.id != myId).toList();
        if (people.isEmpty) {
          return Center(child: Text('No people found for "$term".'));
        }
        return ListView(
          children: [
            for (final u in people) _PersonTile(user: u, showUsername: true),
          ],
        );
      },
    );
  }
}

class _PersonTile extends ConsumerWidget {
  const _PersonTile({required this.user, this.showUsername = false});
  final AppUser user;
  final bool showUsername;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(friendStateProvider(user.id));
    final isMe = ref.watch(authProvider.select((s) => s.user?.id)) == user.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () => openProfile(context, user.id),
      leading: _Avatar(user),
      title: Text(_nameOf(user)),
      subtitle: showUsername ? Text('@${user.username}') : null,
      trailing: isMe || status == null
          ? null
          : switch (status) {
              FriendStatus.friends => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Friends',
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.w500)),
                ),
              FriendStatus.requested => TextButton(
                  onPressed: () => confirmCancelRequest(context, ref, user),
                  child: const Text('Requested',
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.w500)),
                ),
              FriendStatus.incoming => TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref
                          .read(requestedProvider.notifier)
                          .acceptRequest(user.id);
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Could not accept: $e')),
                      );
                    }
                  },
                  child: const Text('Accept',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.w600)),
                ),
              FriendStatus.none => TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref
                          .read(requestedProvider.notifier)
                          .follow(user.id);
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Could not send request: $e')),
                      );
                    }
                  },
                  child: Text('Follow',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
            },
    );
  }
}