
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'auth_provider.dart';
import 'sounds.dart';

class LikesState {
  final Set<int> likedIds;

  final Map<int, int> counts;

  final Set<int> pending;

  const LikesState({
    this.likedIds = const {},
    this.counts = const {},
    this.pending = const {},
  });

  LikesState copyWith({
    Set<int>? likedIds,
    Map<int, int>? counts,
    Set<int>? pending,
  }) {
    return LikesState(
      likedIds: likedIds ?? this.likedIds,
      counts: counts ?? this.counts,
      pending: pending ?? this.pending,
    );
  }

  bool isLiked(int postId) => likedIds.contains(postId);

  int displayLikes(int postId, int serverLikes) =>
      counts[postId] ?? serverLikes;
}

class LikesNotifier extends Notifier<LikesState> {
  @override
  LikesState build() {
    final userId = ref.watch(authProvider.select((s) => s.user?.id));
    if (userId != null) {
      Future.microtask(refresh);
    }
    return const LikesState();
  }

  Future<void> refresh() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    try {
      final ids = await api.getLikedPostIds(userId);
      if (ref.read(authProvider).user?.id != userId) return;
      state = LikesState(likedIds: ids);
    } catch (_) {}
  }

  Future<void> toggle(int postId, int currentCount) async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    if (state.pending.contains(postId)) return;

    final wasLiked = state.isLiked(postId);
    final priorCount = state.counts[postId];
    final newCount = wasLiked
        ? (currentCount > 0 ? currentCount - 1 : 0)
        : currentCount + 1;

    Sounds.tap();

    _set(postId, liked: !wasLiked, count: newCount, pending: true);

    try {
      if (wasLiked) {
        await api.unlikePost(postId, userId);
      } else {
        await api.likePost(postId, userId);
      }
      _set(postId, liked: !wasLiked, count: newCount, pending: false);
    } catch (e) {
      _set(postId, liked: wasLiked, count: priorCount, pending: false);
      rethrow;
    }
  }

  void _set(int postId,
      {required bool liked, required int? count, required bool pending}) {
    final likedIds = {...state.likedIds};
    final counts = {...state.counts};
    final pendingSet = {...state.pending};

    liked ? likedIds.add(postId) : likedIds.remove(postId);
    count == null ? counts.remove(postId) : counts[postId] = count;
    pending ? pendingSet.add(postId) : pendingSet.remove(postId);

    state = state.copyWith(
      likedIds: likedIds,
      counts: counts,
      pending: pendingSet,
    );
  }
}

final likesProvider =
    NotifierProvider<LikesNotifier, LikesState>(LikesNotifier.new);