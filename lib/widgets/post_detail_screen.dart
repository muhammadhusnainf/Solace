import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';
import '../auth_provider.dart';
import '../comments_provider.dart';
import '../feed_provider.dart';
import '../models.dart';
import '../profile_provider.dart';
import '../screens/profile_screen.dart';
import '../search_provider.dart';
import '../sounds.dart';
import 'comment_input_bar.dart';
import 'confirm_dialog.dart';
import 'post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.post});
  final Post post;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _deleting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    setState(() => _sending = true);
    try {
      await api.addComment(userId, widget.post.id, text);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post comment: $e')),
        );
      }
      return;
    }

    _controller.clear();
    Sounds.tap();
    ref.invalidate(commentsProvider(widget.post.id));
    try {
      await ref.read(commentsProvider(widget.post.id).future);
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Post',
      message: 'Are you sure you want to delete this post? '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      await api.deletePost(widget.post.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete post: $e')),
      );
      return;
    }

    ref.invalidate(feedProvider);
    ref.invalidate(userPostsProvider(widget.post.userId));
    ref.invalidate(searchProvider);
    Sounds.success();
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Post deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(commentsProvider(widget.post.id));
    final user = ref.watch(authProvider).user;
    final myAvatar = user == null
        ? null
        : ref.watch(userProfileProvider(user.id)).maybeWhen(
              data: (u) => u.profilePicUrl,
              orElse: () => user.profilePicUrl,
            );

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                PostCard(post: widget.post),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Comments',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                comments.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load comments: $err'),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text('No comments yet.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final c in list) _CommentTile(comment: c),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (user != null && user.id == widget.post.userId)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Center(
                      child: FilledButton(
                        onPressed: _deleting ? null : _delete,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: _deleting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Delete Post'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (user != null)
            CommentInputBar(
              controller: _controller,
              sending: _sending,
              avatarUrl: myAvatar,
              onSend: _send,
            ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final Comment comment;

  Future<void> _open(BuildContext context) async {
    if (comment.userId != 0) {
      openProfile(context, comment.userId);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final found = await api.search(comment.username);
      final match = found.users.where((u) => u.username == comment.username);
      if (match.isNotEmpty && context.mounted) {
        openProfile(context, match.first.id);
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPic =
        comment.profilePicUrl != null && comment.profilePicUrl!.isNotEmpty;
    return ListTile(
      dense: true,
      onTap: comment.userId == 0 && comment.username.isEmpty
          ? null
          : () => _open(context),
      leading: CircleAvatar(
        radius: 16,
        backgroundImage: hasPic ? NetworkImage(comment.profilePicUrl!) : null,
        child: hasPic ? null : const Icon(Icons.person, size: 18),
      ),
      title: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: comment.fullName.isNotEmpty
                  ? comment.fullName
                  : comment.username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: '  '),
            TextSpan(text: comment.comment),
          ],
        ),
      ),
    );
  }
}