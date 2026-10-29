import 'package:flutter/material.dart';
import '../cached_image.dart';

class CommentInputBar extends StatelessWidget {
  const CommentInputBar({
    required this.controller,
    this.focusNode,
    required this.sending,
    required this.avatarUrl,
    required this.onSend,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool sending;
  final String? avatarUrl;
  final VoidCallback onSend;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPic = avatarUrl != null && avatarUrl!.isNotEmpty;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide(color: color, width: width),
        );

    return Material(
      color: scheme.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: hasPic ? cachedImage(avatarUrl!) : null,
                  child: hasPic ? null : const Icon(Icons.person, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: autofocus,
                  readOnly: sending,
                  minLines: 1,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 16),
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(
                        fontSize: 16, color: scheme.onSurfaceVariant),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    border: border(scheme.outlineVariant),
                    enabledBorder: border(scheme.outlineVariant),
                    focusedBorder: border(scheme.primary, 2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final canSend = value.text.trim().isNotEmpty && !sending;
                  return SizedBox(
                    width: 52,
                    height: 52,
                    child: sending
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : IconButton.filled(
                            iconSize: 26,
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              fixedSize: const Size(52, 52),
                              minimumSize: const Size(52, 52),
                            ),
                            onPressed: canSend ? onSend : null,
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}