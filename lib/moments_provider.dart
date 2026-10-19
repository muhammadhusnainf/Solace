import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'auth_provider.dart';
import 'models.dart';

final momentsProvider = FutureProvider<List<MomentGroup>>((ref) async {
  final myId = ref.watch(authProvider.select((s) => s.user?.id));

  // a broken moments call should never take the feed down with it
  List<Moment> moments;
  try {
    moments = await api.getMoments();
  } catch (_) {
    moments = [];
  }

  final active = moments.where((m) => m.isActive).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final byUser = <int, List<Moment>>{};
  for (final m in active) {
    byUser.putIfAbsent(m.userId, () => []).add(m);
  }

  final groups = byUser.entries
      .map((e) => MomentGroup(
            userId: e.key,
            username: e.value.last.username,
            profilePicUrl: e.value.last.profilePicUrl,
            moments: e.value,
          ))
      .toList();

  // mine first, then whoever posted most recently
  groups.sort((a, b) {
    if (a.userId == myId) return -1;
    if (b.userId == myId) return 1;
    return b.latest.compareTo(a.latest);
  });
  return groups;
});

class SeenMomentsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    ref.watch(authProvider.select((s) => s.user?.id));
    return {};
  }

  void markSeen(int id) {
    if (state.contains(id)) return;
    state = {...state, id};
  }
}

final seenMomentsProvider =
    NotifierProvider<SeenMomentsNotifier, Set<int>>(SeenMomentsNotifier.new);
