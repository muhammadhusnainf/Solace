import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'auth_provider.dart';
import 'models.dart';

final momentsProvider = FutureProvider<List<MomentGroup>>((ref) async {
  final myId = ref.watch(authProvider.select((s) => s.user?.id));

  final moments = await api.getMoments();

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

  groups.sort((a, b) {
    if (a.userId == myId) return -1;
    if (b.userId == myId) return 1;
    return b.latest.compareTo(a.latest);
  });
  return groups;
}, retry: (_, _) => null);

class SeenMomentsNotifier extends Notifier<Set<int>> {
  final _storage = const FlutterSecureStorage();
  int? _userId;

  String get _key => 'seen_moments_$_userId';

  @override
  Set<int> build() {
    _userId = ref.watch(authProvider.select((s) => s.user?.id));
    ref.listen<AsyncValue<List<MomentGroup>>>(momentsProvider, (_, next) {
      final groups = next.value;
      if (groups != null) _prune(groups);
    });
    if (_userId != null) _load();
    return {};
  }

  Future<void> _load() async {
    final owner = _userId;
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty || owner != _userId) return;
      final saved = raw.split(',').map(int.tryParse).whereType<int>();
      state = {...state, ...saved};
      final groups = ref.read(momentsProvider).value;
      if (groups != null) _prune(groups);
    } catch (_) {}
  }

  void _prune(List<MomentGroup> groups) {
    final active = {
      for (final g in groups)
        for (final m in g.moments) m.id,
    };
    final kept = state.where(active.contains).toSet();
    if (kept.length == state.length) return;
    state = kept;
    _save();
  }

  void markSeen(int id) {
    if (state.contains(id)) return;
    state = {...state, id};
    _save();
  }

  Future<void> _save() async {
    if (_userId == null) return;
    try {
      await _storage.write(key: _key, value: state.join(','));
    } catch (_) {}
  }
}

final seenMomentsProvider =
    NotifierProvider<SeenMomentsNotifier, Set<int>>(SeenMomentsNotifier.new);
