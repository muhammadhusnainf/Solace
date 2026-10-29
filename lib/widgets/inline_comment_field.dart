import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';
import '../auth_provider.dart';
import '../comments_provider.dart';
import '../profile_provider.dart';
import '../cached_image.dart';

class InlineCommentField extends ConsumerStatefulWidget {
  const InlineCommentField({super.key, required this.postId});
  final int postId;

  @override
  ConsumerState<InlineCommentField> createState() =>
      _InlineCommentFieldState();
}

class _InlineCommentFieldState extends ConsumerState<InlineCommentField> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final userId = ref.read(authProvider).user?.id;
    if (text.isEmpty || userId == null || _sending) return;

    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sending = true);
    try {
      await api.addComment(userId, widget.postId, text);
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not post comment: $e')),
      );
      return;
    }

    container.invalidate(commentsProvider(widget.postId));
    if (mounted) {
      _controller.clear();
      FocusScope.of(context).unfocus();
      setState(() => _sending = false);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Comment posted'),
        duration: Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    if (me == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final avatarUrl = ref.watch(userProfileProvider(me.id)).maybeWhen(
          data: (u) => u.profilePicUrl,
          orElse: () => me.profilePicUrl,
        );
    final hasPic = avatarUrl != null && avatarUrl.isNotEmpty;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: color, width: width),
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: hasPic ? cachedImage(avatarUrl) : null,
              onBackgroundImageError: hasPic ? (_, _) {} : null,
              child: hasPic ? null : const Icon(Icons.person, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                readOnly: _sending,
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(
                      fontSize: 14, color: scheme.onSurfaceVariant),
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: border(scheme.outlineVariant),
                  enabledBorder: border(scheme.outlineVariant),
                  focusedBorder: border(scheme.primary, 1.5),
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: _sending
                  ? const Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) => TextButton(
                        onPressed:
                            value.text.trim().isEmpty ? null : _send,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(56, 36),
                        ),
                        child: const Text('Post',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}