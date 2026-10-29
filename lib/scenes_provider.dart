import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'auth_provider.dart';
import 'models.dart';

class ScenesNotifier extends AsyncNotifier<List<Scene>> {
  static const _pageSize = 10;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  Future<List<Scene>> build() async {
    ref.watch(authProvider.select((s) => s.user?.id));
    _hasMore = true;
    final first = await api.getScenes(limit: _pageSize, offset: 0);
    _hasMore = first.length >= _pageSize;
    return first;
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final next =
          await api.getScenes(limit: _pageSize, offset: current.length);
      _hasMore = next.length >= _pageSize;
      final latest = state.value ?? current;
      final known = latest.map((s) => s.id).toSet();
      state = AsyncData([
        ...latest,
        ...next.where((s) => !known.contains(s.id)),
      ]);
    } catch (_) {
    } finally {
      _loadingMore = false;
    }
  }

  void addScene(Scene scene) {
    final list = state.value ?? <Scene>[];
    if (list.any((s) => s.id == scene.id)) return;
    state = AsyncData([scene, ...list]);
  }

  void _patch(int id, Scene Function(Scene) change) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([for (final s in list) s.id == id ? change(s) : s]);
  }

  Future<void> toggleLike(int id) async {
    final list = state.value;
    if (list == null) return;
    final index = list.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final before = list[index];

    _patch(
      id,
      (s) => s.copyWith(
        isLiked: !s.isLiked,
        likesCount: max(0, s.likesCount + (s.isLiked ? -1 : 1)),
      ),
    );

    try {
      final result = await api.toggleSceneLike(id);
      _patch(
        id,
        (s) => s.copyWith(isLiked: result.liked, likesCount: result.count),
      );
    } catch (_) {
      _patch(id, (s) => before);
    }
  }
}

final scenesProvider =
    AsyncNotifierProvider<ScenesNotifier, List<Scene>>(ScenesNotifier.new);

final sceneCommentsProvider = FutureProvider.autoDispose
    .family<List<SceneComment>, int>((ref, sceneId) {
  return api.getSceneComments(sceneId);
});

class SceneMuteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final sceneMuteProvider =
    NotifierProvider<SceneMuteNotifier, bool>(SceneMuteNotifier.new);
