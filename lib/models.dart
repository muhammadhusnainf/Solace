class AppUser {
  final int id;
  final String fullName;
  final String username;
  final String email;
  final String? profilePicUrl;

  AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.profilePicUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      fullName: json['full_name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      profilePicUrl: fixImageUrl(json['profile_pic_url']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'username': username,
        'email': email,
        'profile_pic_url': profilePicUrl,
      };
}

class Post {
  final int id;
  final int userId;
  final String description;
  final String? imageUrl;
  final String resourceType;
  final int likes;
  final String authorName;
  final String? authorProfilePicUrl;

  Post({
    required this.id,
    required this.userId,
    required this.description,
    this.imageUrl,
    this.resourceType = 'image',
    this.likes = 0,
    this.authorName = '',
    this.authorProfilePicUrl,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      description: json['description']?.toString() ?? '',
      imageUrl: fixImageUrl(json['imageUrl']?.toString()),
      resourceType: json['resource_type']?.toString() ?? 'image',
      likes: asInt(json['likes']),
      authorName: json['full_name']?.toString() ?? '',
      authorProfilePicUrl: fixImageUrl(json['profile_pic_url']?.toString()),
    );
  }

  bool get isVideo => resourceType == 'video';

  static int asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}

class SearchResults {
  final List<AppUser> users;
  final List<Post> posts;

  const SearchResults({this.users = const [], this.posts = const []});

  bool get isEmpty => users.isEmpty && posts.isEmpty;
}

class Comment {
  final int id;
  final int userId;
  final int postId;
  final String comment;
  final String fullName;
  final String username;
  final String? profilePicUrl;

  const Comment({
    required this.id,
    required this.userId,
    required this.postId,
    required this.comment,
    this.fullName = '',
    this.username = '',
    this.profilePicUrl,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    String text() {
      for (final k in ['comment', 'content', 'text']) {
        final v = json[k];
        if (v != null) return v.toString();
      }
      return '';
    }

    int authorId() {
      for (final k in ['user_id', 'userId', 'commenter_id', 'author_id']) {
        if (json[k] != null) return Post.asInt(json[k]);
      }
      final u = json['user'];
      if (u is Map) return Post.asInt(u['id']);
      return 0;
    }

    return Comment(
      id: Post.asInt(json['id']),
      userId: authorId(),
      postId: Post.asInt(json['post_id']),
      comment: text(),
      fullName: json['full_name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      profilePicUrl: fixImageUrl(json['profile_pic_url']?.toString()),
    );
  }
}

class ChatMessage {
  final int? id;
  final int? senderId;
  final int? receiverId;
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    this.id,
    this.senderId,
    this.receiverId,
    required this.text,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    dynamic first(List<String> keys) {
      for (final k in keys) {
        if (json[k] != null) return json[k];
      }
      return null;
    }

    int? asId(dynamic v) {
      if (v is Map) v = v['id'];
      if (v == null) return null;
      return v is int ? v : int.tryParse(v.toString());
    }

    DateTime? asTime(dynamic v) {
      if (v == null) return null;
      if (v is num) {
        final ms = v > 1000000000000 ? v.toInt() : (v * 1000).toInt();
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    return ChatMessage(
      id: asId(json['id']),
      senderId: asId(first(['sender_id', 'user_id', 'from_id', 'from', 'sender'])),
      receiverId:
          asId(first(['receiver_id', 'recipient_id', 'to_id', 'to', 'receiver'])),
      text: first(['message', 'content', 'text', 'body'])?.toString() ?? '',
      createdAt: asTime(
          first(['created_at', 'createdAt', 'timestamp', 'sent_at', 'time', 'date'])),
    );
  }

  bool isMine({required int myId, required int friendId}) {
    if (senderId != null) return senderId == myId;
    if (receiverId != null) return receiverId == friendId;
    return false;
  }
}

class Moment {
  final int id;
  final int userId;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String username;
  final String? profilePicUrl;

  Moment({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.createdAt,
    required this.expiresAt,
    this.username = '',
    this.profilePicUrl,
  });

  factory Moment.fromJson(Map<String, dynamic> json) {
    return Moment(
      id: Post.asInt(json['id']),
      userId: Post.asInt(json['user_id']),
      imageUrl: fixImageUrl(json['image_url']?.toString()) ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 24)),
      username: json['username']?.toString() ?? '',
      profilePicUrl: fixImageUrl(json['profile_pic_url']?.toString()),
    );
  }

  bool get isActive => expiresAt.isAfter(DateTime.now());
}

class MomentGroup {
  final int userId;
  final String username;
  final String? profilePicUrl;
  final List<Moment> moments;

  MomentGroup({
    required this.userId,
    required this.username,
    required this.moments,
    this.profilePicUrl,
  });

  DateTime get latest => moments.last.createdAt;
}

class Scene {
  final int id;
  final int userId;
  final String videoUrl;
  final String? thumbnailUrl;
  final String caption;
  final String username;
  final String? profilePicUrl;
  final int likesCount;
  final bool isLiked;

  const Scene({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.thumbnailUrl,
    this.caption = '',
    this.username = '',
    this.profilePicUrl,
    this.likesCount = 0,
    this.isLiked = false,
  });

  factory Scene.fromJson(Map<String, dynamic> json) {
    final liked = json['is_liked'];
    return Scene(
      id: Post.asInt(json['id']),
      userId: Post.asInt(json['user_id']),
      videoUrl: json['video_url']?.toString() ?? '',
      thumbnailUrl: fixImageUrl(json['thumbnail_url']?.toString()),
      caption: json['caption']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      profilePicUrl: fixImageUrl(json['profile_pic_url']?.toString()),
      likesCount: Post.asInt(json['likes_count']),
      isLiked: liked == true || liked?.toString() == '1',
    );
  }

  Scene copyWith({int? likesCount, bool? isLiked}) {
    return Scene(
      id: id,
      userId: userId,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      username: username,
      profilePicUrl: profilePicUrl,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

class SceneComment {
  final int id;
  final int userId;
  final String content;
  final DateTime? createdAt;
  final String username;
  final String? profilePicUrl;

  const SceneComment({
    required this.id,
    required this.userId,
    required this.content,
    this.createdAt,
    this.username = '',
    this.profilePicUrl,
  });

  factory SceneComment.fromJson(Map<String, dynamic> json) {
    return SceneComment(
      id: Post.asInt(json['id']),
      userId: Post.asInt(json['user_id']),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      username: json['username']?.toString() ?? '',
      profilePicUrl: fixImageUrl(json['profile_pic_url']?.toString()),
    );
  }
}

class Journey {
  final int id;
  final String title;
  final String description;
  final String? coverUrl;
  final String visibility;
  final String status;

  const Journey({
    required this.id,
    required this.title,
    this.description = '',
    this.coverUrl,
    this.visibility = 'private',
    this.status = 'ongoing',
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      id: Post.asInt(json['id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      coverUrl: fixImageUrl((json['cover_url'] ?? json['cover'])?.toString()),
      visibility: json['visibility']?.toString() ?? 'private',
      status: json['status']?.toString() ?? 'ongoing',
    );
  }

  bool get isCompleted => status == 'completed';

  String get visibilityLabel {
    switch (visibility) {
      case 'public':
        return 'Public';
      case 'followers':
        return 'Followers';
      default:
        return 'Only me';
    }
  }
}

class JourneyMedia {
  final int id;
  final String url;
  final String type;

  const JourneyMedia({required this.id, required this.url, this.type = 'image'});

  factory JourneyMedia.fromJson(Map<String, dynamic> json) {
    return JourneyMedia(
      id: Post.asInt(json['id']),
      url: fixImageUrl(json['media_url']?.toString()) ?? '',
      type: json['media_type']?.toString() ?? 'image',
    );
  }

  bool get isVideo => type == 'video';
}

class JourneyEntry {
  final int id;
  final String title;
  final String content;
  final DateTime entryDate;
  final List<JourneyMedia> media;

  const JourneyEntry({
    required this.id,
    required this.entryDate,
    this.title = '',
    this.content = '',
    this.media = const [],
  });

  factory JourneyEntry.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['media'];
    return JourneyEntry(
      id: Post.asInt(json['id']),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      entryDate: DateTime.tryParse(json['entry_date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      media: rawMedia is List
          ? rawMedia
              .whereType<Map>()
              .map((e) => JourneyMedia.fromJson(Map<String, dynamic>.from(e)))
              .where((m) => m.url.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

String formatDate(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String? fixImageUrl(String? url) {
  if (url == null) return null;
  final t = url.trim();
  if (t.contains('res.cloudinary.com') && t.toLowerCase().endsWith('.avif')) {
    return '${t.substring(0, t.length - 5)}.jpg';
  }
  return t;
}