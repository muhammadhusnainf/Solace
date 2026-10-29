import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';
import '../auth_provider.dart';
import '../models.dart';
import '../profile_provider.dart';
import '../scenes_provider.dart';
import 'comment_input_bar.dart';

Future<void> showSceneComments(BuildContext context, int sceneId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _SceneCommentSheet(sceneId: sceneId),
  );
}

class _SceneCommentSheet extends ConsumerStatefulWidget {
  const _SceneCommentSheet({required this.sceneId});

  final int sceneId;

  @override
  ConsumerState<_SceneCommentSheet> createState() => _SceneCommentSheetState();
}

class _SceneCommentSheetState extends ConsumerState<_SceneCommentSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await api.addSceneComment(widget.sceneId, text);
      ref.invalidate(sceneCommentsProvider(widget.sceneId));
      _controller.clear();
      if (mounted) setState(() => _sending = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Could not post comment: $e';
      });
    }
  }

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    final comments = ref.watch(sceneCommentsProvider(widget.sceneId));
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final height = min(media.size.height * 0.7, media.size.height - keyboard - 120);

    final avatarUrl = me == null
        ? null
        : ref.watch(userProfileProvider(me.id)).maybeWhen(
              data: (u) => u.profilePicUrl,
              orElse: () => me.profilePicUrl,
            );

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: max(height, 240),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text('Comments',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: comments.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(sceneCommentsProvider(widget.sceneId)),
                    child: const Text('Could not load comments, tap to retry'),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('No comments yet. Start the conversation.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _CommentTile(
                      comment: list[i],
                      ago: _ago(list[i].createdAt),
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            CommentInputBar(
              controller: _controller,
              sending: _sending,
              avatarUrl: avatarUrl,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.ago});

  final SceneComment comment;
  final String ago;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPic =
        comment.profilePicUrl != null && comment.profilePicUrl!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage: hasPic ? NetworkImage(comment.profilePicUrl!) : null,
          child: hasPic ? null : const Icon(Icons.person, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      comment.username.isNotEmpty ? comment.username : 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(ago,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 2),
              Text(comment.content),
            ],
          ),
        ),
      ],
    );
  }
}
