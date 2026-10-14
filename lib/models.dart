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

String? fixImageUrl(String? url) {
  if (url == null) return null;
  final t = url.trim();
  if (t.contains('res.cloudinary.com') && t.toLowerCase().endsWith('.avif')) {
    return '${t.substring(0, t.length - 5)}.jpg';
  }
  return t;
}