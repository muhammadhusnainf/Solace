import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  static const String baseUrl = 'https://social-media-app-five-rust.vercel.app';

  late final Dio dio;

  final _storage = const FlutterSecureStorage();
  static const _cookieKey = 'auth_cookie';
  static const _userKey = 'auth_user';

  void Function()? onUnauthorized;

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (status) => status != null && status < 500,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookie = await _storage.read(key: _cookieKey);
        if (cookie != null && cookie.isNotEmpty) {
          options.headers['Cookie'] = cookie;
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        final setCookie = response.headers.map['set-cookie'];
        if (setCookie != null && setCookie.isNotEmpty) {
          final nameValue = setCookie.first.split(';').first.trim();
          final eq = nameValue.indexOf('=');
          if (eq != -1 && eq < nameValue.length - 1) {
            await _storage.write(key: _cookieKey, value: nameValue);
          }
        }

        final path = response.requestOptions.path;
        final isAuthCall =
            path.startsWith('/api/auth/') || path == '/api/issignedin';
        if (response.statusCode == 401 && !isAuthCall) {
          await clearSession();
          onUnauthorized?.call();
        }
        handler.next(response);
      },
    ));
  }

  void _check(Response res, {String fallback = 'Something went wrong'}) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    throw ApiException(_messageFrom(res.data) ?? fallback, statusCode: code);
  }

  String? _messageFrom(dynamic data) {
    if (data is Map) {
      final m = data['message'] ?? data['error'] ?? data['detail'];
      if (m != null && m.toString().trim().isNotEmpty) return m.toString();
    } else if (data is String) {
      final s = data.trim();
      if (s.isNotEmpty && s.length < 200 && !s.startsWith('<')) return s;
    }
    return null;
  }

  AppUser _userFrom(dynamic data) {
    if (data is Map) {
      final inner = data['user'];
      final map = inner is Map ? inner : data;
      return AppUser.fromJson(Map<String, dynamic>.from(map));
    }
    throw ApiException('Unexpected response from the server');
  }

  Future<AppUser> signup({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await dio.post('/api/auth/signup', data: {
      'full_name': fullName,
      'username': username,
      'email': email,
      'password': password,
    });
    _check(res, fallback: 'Sign up failed');
    final user = _userFrom(res.data);
    await saveUser(user);

    if (!await hasSavedLogin()) {
      return login(email: email, password: password);
    }
    return user;
  }

  Future<AppUser> login({required String email, required String password}) async {
    final res = await dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
    _check(res, fallback: 'Login failed');
    final user = _userFrom(res.data);
    await saveUser(user);
    return user;
  }

  Future<void> logout() async {
    try {
      await dio.post('/api/auth/logout');
    } finally {
      await clearSession();
    }
  }

  Future<bool> isSignedIn() async {
    final res = await dio.get('/api/issignedin');
    return res.statusCode == 200;
  }

  Future<bool> hasSavedLogin() async {
    final cookie = await _storage.read(key: _cookieKey);
    return cookie != null && cookie.isNotEmpty;
  }

  Future<void> saveUser(AppUser user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  Future<AppUser?> loadUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _cookieKey);
    await _storage.delete(key: _userKey);
  }

  Future<void> createPost({
    required int userId,
    required String description,
    required Uint8List imageBytes,
    required String imageName,
    String? imageMime,
  }) async {
    final form = FormData.fromMap({
      'description': description,
      'user_id': userId.toString(),
      'file': MultipartFile.fromBytes(
        imageBytes,
        filename: imageName,
        contentType: DioMediaType.parse(imageMime ?? 'image/jpeg'),
      ),
    });
    final res = await dio.post(
      '/api/posts',
      data: form,
      options: Options(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    _check(res, fallback: 'Could not create post');
  }

  Future<List<Post>> getFeed() async {
    final res = await dio.get('/api/posts');
    _check(res, fallback: 'Could not load feed');
    return (res.data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<Post> getPost(int postId) async {
    final res = await dio.get('/api/posts/$postId');
    _check(res, fallback: 'Could not load post');
    return Post.fromJson(res.data);
  }

  Future<List<Post>> getUserPosts(int userId) async {
    final res = await dio.get('/api/userposts/$userId');
    if (res.statusCode == 404) return [];
    _check(res, fallback: 'Could not load posts');
    if (res.data is! List) return [];
    return (res.data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<void> deletePost(int postId) async {
    final res = await dio.delete('/api/posts/$postId');
    _check(res, fallback: 'Could not delete post');
  }

  Future<void> likePost(int postId, int userId) async {
    final res = await dio.patch('/api/posts/like/$postId/$userId');
    _check(res, fallback: 'Could not like post');
  }

  Future<void> unlikePost(int postId, int userId) async {
    final res = await dio.patch('/api/posts/unlike/$postId/$userId');
    _check(res, fallback: 'Could not unlike post');
  }

  Future<Set<int>> getLikedPostIds(int userId) async {
    final res = await dio.get('/api/liked_posts/$userId');
    _check(res, fallback: 'Could not load liked posts');
    return (res.data as List)
        .map((e) => Post.asInt((e as Map)['id']))
        .toSet();
  }

  Future<AppUser> getUser(int userId) async {
    final res = await dio.get('/api/users/$userId');
    _check(res, fallback: 'Could not load profile');
    return _userFrom(res.data);
  }

  Future<void> updateProfileImage({
    required int userId,
    required Uint8List imageBytes,
    required String imageName,
    String? imageMime,
  }) async {
    final form = FormData.fromMap({
      'profileImage': MultipartFile.fromBytes(
        imageBytes,
        filename: imageName,
        contentType: DioMediaType.parse(imageMime ?? 'image/jpeg'),
      ),
    });
    final res = await dio.patch('/api/profile_image/$userId', data: form);
    _check(res, fallback: 'Could not update profile photo');
  }

  Future<void> addComment(int userId, int postId, String content) async {
    final res = await dio.post(
      '/api/comments/$userId/$postId',
      data: {'content': content, 'comment': content},
    );
    if (res.statusCode == null || res.statusCode! >= 300) {
      debugPrint('addComment failed: ${res.statusCode} ${res.data}');
    }
    _check(res, fallback: 'Could not add comment');
  }

  Future<List<dynamic>> getComments(int postId) async {
    final res = await dio.get('/api/comments/$postId');
    if (res.statusCode == 404) return [];
    _check(res, fallback: 'Could not load comments');
    final data = res.data;
    if (data is List) return data;
    if (data is Map && data['comments'] is List) return data['comments'] as List;
    return [];
  }

  Future<SearchResults> search(String term) async {
    final res = await dio.get('/api/search/${Uri.encodeComponent(term)}');
    if (res.statusCode == 404) return const SearchResults();
    _check(res, fallback: 'Search failed');

    var data = res.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }

    final users = <AppUser>[];
    final posts = <Post>[];

    void walk(dynamic node) {
      if (node is List) {
        node.forEach(walk);
      } else if (node is Map) {
        final map = Map<String, dynamic>.from(node);
        if (map.containsKey('username')) {
          users.add(AppUser.fromJson(map));
        } else if (map.containsKey('description') ||
            map.containsKey('imageUrl')) {
          posts.add(Post.fromJson(map));
        } else {
          map.values.forEach(walk);
        }
      }
    }

    walk(data);

    if (users.isEmpty && posts.isEmpty) {
      final raw = data.toString();
      debugPrint('search("$term") found nothing. Response type: '
          '${data.runtimeType}, body: '
          '${raw.length > 400 ? raw.substring(0, 400) : raw}');
    }
    return SearchResults(users: users, posts: posts);
  }

  Future<Response> _friendCall(String what, Future<Response> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      debugPrint('$what failed: ${e.type} | ${e.message} | '
          '${e.requestOptions.method} ${e.requestOptions.uri}');
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw ApiException('The server took too long to respond. '
              'Please try again.');
        case DioExceptionType.connectionError:
          throw ApiException('Could not reach the server. '
              'Check your connection.');
        default:
          throw ApiException(e.message ?? 'Network error');
      }
    }
  }

  List<AppUser> _usersFrom(Response res) {
    if (res.statusCode == 404 || res.data is! List) return [];
    return (res.data as List)
        .whereType<Map>()
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<AppUser>> getFriendSuggestions(int userId) async {
    final res = await _friendCall('suggestions',
        () => dio.get('/api/friendsuggestions/$userId'));
    if (res.statusCode != 404) _check(res, fallback: 'Could not load suggestions');
    return _usersFrom(res);
  }

  Future<void> sendFriendRequest(int senderId, int receiverId) async {
    if (senderId == receiverId) {
      throw ApiException("You can't send a friend request to yourself");
    }
    final res = await _friendCall(
      'sendFriendRequest',
      () => dio.post(
        '/api/friend_requests/$senderId/$receiverId',
        data: <String, dynamic>{},
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      ),
    );
    _check(res, fallback: 'Could not send friend request');
  }

  Future<List<AppUser>> getIncomingFriendRequests(int userId) async {
    final res = await _friendCall('incomingRequests',
        () => dio.get('/api/friend_requests/$userId'));
    if (res.statusCode != 404) _check(res, fallback: 'Could not load friend requests');
    return _usersFrom(res);
  }

  Future<void> acceptFriendRequest(int senderId, int receiverId) async {
    final res = await _friendCall(
      'acceptFriendRequest',
      () => dio.patch('/api/friend_request/$senderId/$receiverId',
          data: <String, dynamic>{}),
    );
    _check(res, fallback: 'Could not accept friend request');
  }

  Future<bool> hasFriendRequest(int senderId, int receiverId) async {
    final res = await _friendCall('hasFriendRequest',
        () => dio.get('/api/sent_friend_request/$senderId/$receiverId'));
    _check(res, fallback: 'Could not load request status');
    final d = res.data;
    return d == true || d.toString().toLowerCase() == 'true';
  }

  Future<List<AppUser>> getFriends(int userId) async {
    final res = await _friendCall(
        'getFriends', () => dio.get('/api/friends/$userId'));
    if (res.statusCode != 404) _check(res, fallback: 'Could not load friends');
    return _usersFrom(res);
  }

  Future<void> removeFriend(int user1Id, int user2Id) async {
    final res = await _friendCall('removeFriend',
        () => dio.delete('/api/friends/$user1Id/$user2Id'));
    _check(res, fallback: 'Could not remove friend');
  }

  Future<List<ChatMessage>> getChat(int friendId, int myId) async {
    final res = await _friendCall(
        'getChat', () => dio.get('/api/chats/$friendId/$myId'));
    if (res.statusCode == 404) return [];
    _check(res, fallback: 'Could not load messages');

    var data = res.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }
    if (data is Map) {
      data = data['messages'] ?? data['chats'] ?? data['data'];
    }
    if (data is! List) return [];

    final out = <ChatMessage>[];
    for (final e in data) {
      if (e is! Map) continue;
      try {
        out.add(ChatMessage.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {
      }
    }
    return out;
  }

  Future<void> sendChatMessage(int friendId, String message) async {
    final res = await _friendCall(
      'sendChatMessage',
      () => dio.post('/api/chats/$friendId', data: {'message': message}),
    );
    _check(res, fallback: 'Could not send message');
  }
}

final api = ApiClient();