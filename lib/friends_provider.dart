
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'auth_provider.dart';
import 'models.dart';
import 'sounds.dart';

final suggestionsProvider =
    FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final userId = ref.watch(authProvider.select((s) => s.user?.id));
  if (userId == null) return [];
  final all = await api.getFriendSuggestions(userId);
  return all.where((u) => u.id != userId).toList();
});

class RequestedNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    ref.watch(authProvider.select((s) => s.user?.id));
    return {};
  }

  Future<void> follow(int targetId) async {
    final me = ref.read(authProvider).user?.id;
    if (me == null || me == targetId || state.contains(targetId)) return;

    bool theyAskedFirst = false;
    try {
      final incoming = await api.getIncomingFriendRequests(me);
      theyAskedFirst = incoming.any((u) => u.id == targetId);
    } catch (_) {}
    if (theyAskedFirst) {
      await acceptRequest(targetId);
      return;
    }

    state = {...state, targetId};
    try {
      await api.sendFriendRequest(me, targetId);
      ref.read(sentRequestsProvider.notifier).add(targetId);
      Sounds.success();
    } catch (e) {
      try {
        if (await api.hasFriendRequest(me, targetId)) {
          ref.read(sentRequestsProvider.notifier).add(targetId);
          return;
        }
      } catch (_) {
      }
      state = {...state}..remove(targetId);
      rethrow;
    }
  }

  Future<void> cancelRequest(int targetId) async {
    final me = ref.read(authProvider).user?.id;
    if (me == null || me == targetId) return;
    await api.removeFriend(me, targetId);
    if (await api.hasFriendRequest(me, targetId)) {
      throw ApiException('Could not cancel the request');
    }
    state = {...state}..remove(targetId);
    ref.read(sentRequestsProvider.notifier).remove(targetId);
    ref.invalidate(friendStatusProvider(targetId));
    Sounds.tap();
  }

  Future<void> acceptRequest(int senderId) async {
    final me = ref.read(authProvider).user?.id;
    if (me == null) return;
    await api.acceptFriendRequest(senderId, me);
    Sounds.success();
    ref.invalidate(myFriendsProvider);
    ref.invalidate(friendStatusProvider(senderId));
    ref.invalidate(incomingRequestsProvider);
  }

  Future<void> rejectRequest(int senderId) async {
    final me = ref.read(authProvider).user?.id;
    if (me == null) return;
    await api.removeFriend(senderId, me);
    if (await api.hasFriendRequest(senderId, me)) {
      throw ApiException('Could not reject the request');
    }
    ref.invalidate(friendStatusProvider(senderId));
    ref.invalidate(incomingRequestsProvider);
    Sounds.tap();
  }

  Future<void> unfriend(int targetId) async {
    final me = ref.read(authProvider).user?.id;
    if (me == null || me == targetId) return;

    Future<bool> stillFriends() async =>
        (await api.getFriends(me)).any((u) => u.id == targetId);

    await api.removeFriend(me, targetId);
    if (await stillFriends()) {
      await api.removeFriend(targetId, me);
      if (await stillFriends()) {
        throw ApiException('Could not remove friend');
      }
    }
    state = {...state}..remove(targetId);
    ref.invalidate(myFriendsProvider);
    ref.invalidate(friendStatusProvider(targetId));
  }
}

class SentRequestsNotifier extends Notifier<List<int>> {
  static const _storage = FlutterSecureStorage();
  int? _me;

  String get _key => 'sent_requests_$_me';

  @override
  List<int> build() {
    final me = ref.watch(authProvider.select((s) => s.user?.id));
    _me = me;
    if (me != null) _load(me);
    return [];
  }

  Future<void> _load(int me) async {
    try {
      final raw = await _storage.read(key: 'sent_requests_$me');
      if (raw == null || raw.isEmpty || _me != me) return;
      final saved =
          (jsonDecode(raw) as List).map((e) => int.parse(e.toString()));
      state = [...state, ...saved.where((id) => !state.contains(id))];
    } catch (_) {}
  }

  Future<void> add(int id) async {
    if (_me == null) return;
    state = [id, ...state.where((i) => i != id)].take(50).toList();
    await _save();
  }

  Future<void> remove(int id) async {
    if (_me == null) return;
    state = state.where((i) => i != id).toList();
    await _save();
  }

  Future<void> _save() async {
    try {
      await _storage.write(key: _key, value: jsonEncode(state));
    } catch (_) {}
  }
}

final sentRequestsProvider =
    NotifierProvider<SentRequestsNotifier, List<int>>(SentRequestsNotifier.new);

final requestedProvider =
    NotifierProvider<RequestedNotifier, Set<int>>(RequestedNotifier.new);

enum FriendStatus { none, requested, incoming, friends }

final myFriendsProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final me = ref.watch(authProvider.select((s) => s.user?.id));
  if (me == null) return <AppUser>[];
  return api.getFriends(me);
});

final myFriendIdsProvider = FutureProvider.autoDispose<Set<int>>((ref) async {
  final friends = await ref.watch(myFriendsProvider.future);
  return friends.map((u) => u.id).toSet();
});

final friendStatusProvider =
    FutureProvider.autoDispose.family<FriendStatus, int>((ref, targetId) async {
  final me = ref.watch(authProvider.select((s) => s.user?.id));
  if (me == null || me == targetId) return FriendStatus.none;
  try {
    final ids = await ref.watch(myFriendIdsProvider.future);
    if (ids.contains(targetId)) return FriendStatus.friends;
    final incoming = await ref.watch(incomingRequestsProvider.future);
    if (incoming.any((u) => u.id == targetId)) return FriendStatus.incoming;
    final requestExists = await api.hasFriendRequest(me, targetId);
    return requestExists ? FriendStatus.requested : FriendStatus.none;
  } catch (_) {
    return FriendStatus.none;
  }
});

final incomingRequestsProvider =
    FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final me = ref.watch(authProvider.select((s) => s.user?.id));
  if (me == null) return [];
  final results = await Future.wait([
    api.getIncomingFriendRequests(me),
    ref.watch(myFriendIdsProvider.future),
  ]);
  final requests = results[0] as List<AppUser>;
  final friendIds = results[1] as Set<int>;
  return requests
      .where((u) => u.id != me && !friendIds.contains(u.id))
      .toList();
});

final friendStateProvider =
    Provider.autoDispose.family<FriendStatus?, int>((ref, targetId) {
  final server = ref.watch(friendStatusProvider(targetId)).value;
  final sentNow = ref.watch(requestedProvider).contains(targetId);
  if (server == FriendStatus.friends || server == FriendStatus.incoming) {
    return server;
  }
  if (sentNow) return FriendStatus.requested;
  return server;
});

final pendingSentIdsProvider = Provider.autoDispose<List<int>>((ref) {
  final ids = ref.watch(sentRequestsProvider);
  return [
    for (final id in ids)
      if (ref.watch(friendStateProvider(id)) == FriendStatus.requested) id,
  ];
});