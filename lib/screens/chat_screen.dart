import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';
import '../auth_provider.dart';
import '../models.dart';
import '../sounds.dart';
import 'profile_screen.dart';

void openChat(BuildContext context, AppUser friend) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
  );
}

class _LocalMessage {
  _LocalMessage(this.text) : at = DateTime.now();
  final String text;
  final DateTime at;
  bool sent = false;
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.friend});
  final AppUser friend;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _pollEvery = Duration(seconds: 4);

  final _controller = TextEditingController();
  Timer? _poll;

  List<ChatMessage> _server = [];
  final List<_LocalMessage> _local = [];
  bool _loading = true;
  bool _fetching = false;
  String? _error;
  int? _theirCount;

  @override
  void initState() {
    super.initState();
    _fetch();
    _poll = Timer.periodic(_pollEvery, (_) => _fetch());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final me = ref.read(authProvider).user?.id;
    if (me == null || _fetching) return;
    _fetching = true;
    final confirmed = _local.where((m) => m.sent).toList();
    try {
      final list = await api.getChat(widget.friend.id, me);
      if (list.isNotEmpty && list.every((m) => m.createdAt != null)) {
        final indexed = list.asMap().entries.toList()
          ..sort((a, b) {
            final c = a.value.createdAt!.compareTo(b.value.createdAt!);
            return c != 0 ? c : a.key.compareTo(b.key);
          });
        list
          ..clear()
          ..addAll(indexed.map((e) => e.value));
      }
      if (!mounted) return;
      final theirs = list
          .where((m) => !m.isMine(myId: me, friendId: widget.friend.id))
          .length;
      if (_theirCount != null && theirs > _theirCount!) Sounds.message();
      _theirCount = theirs;
      setState(() {
        _server = list;
        _error = null;
        _loading = false;
        _local.removeWhere(confirmed.contains);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      _fetching = false;
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final local = _LocalMessage(text);
    Sounds.tap();
    setState(() => _local.add(local));

    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.sendChatMessage(widget.friend.id, text);
      if (!mounted) return;
      setState(() => local.sent = true);
      _fetch();
    } catch (e) {
      if (!mounted) return;
      setState(() => _local.remove(local));
      if (_controller.text.isEmpty) _controller.text = text;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider.select((s) => s.user?.id));
    final friend = widget.friend;
    final hasPic =
        friend.profilePicUrl != null && friend.profilePicUrl!.isNotEmpty;

    final items = <_Bubble>[
      for (final m in _server)
        _Bubble(
          text: m.text,
          at: m.createdAt,
          mine: me != null && m.isMine(myId: me, friendId: friend.id),
        ),
      for (final m in _local) _Bubble(text: m.text, at: m.at, mine: true),
    ].reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => openProfile(context, friend.id),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    hasPic ? NetworkImage(friend.profilePicUrl!) : null,
                onBackgroundImageError: hasPic ? (_, __) {} : null,
                child: hasPic ? null : const Icon(Icons.person, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  friend.fullName.isNotEmpty
                      ? friend.fullName
                      : friend.username,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _messages(items)),
          if (_error != null && items.isNotEmpty)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text("Can't reach the chat right now - retrying...",
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          _InputBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }

  Widget _messages(List<_Bubble> items) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (items.isEmpty) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load messages: $_error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _fetch, child: const Text('Retry')),
              ],
            ),
          ),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No messages yet. Say hi!', textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, this.at});
  final String text;
  final bool mine;
  final DateTime? at;

  static String _time(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final hm = '${two(t.hour)}:${two(t.minute)}';
    final today = t.year == now.year && t.month == now.month && t.day == now.day;
    return today ? hm : '${t.day}/${t.month} $hm';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(text, style: TextStyle(color: fg, fontSize: 15)),
              ),
              if (at != null) ...[
                const SizedBox(height: 2),
                Text(_time(at!),
                    style: TextStyle(
                        color: fg.withOpacity(0.7), fontSize: 10)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: 'Send',
              icon: const Icon(Icons.send),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}