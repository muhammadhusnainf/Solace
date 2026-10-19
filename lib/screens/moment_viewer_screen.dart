import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models.dart';
import '../moments_provider.dart';
import 'profile_screen.dart';

Future<void> openMoments(
  BuildContext context,
  List<MomentGroup> groups,
  int start,
) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MomentViewerScreen(groups: groups, initialGroup: start),
    ),
  );
}

class MomentViewerScreen extends ConsumerStatefulWidget {
  const MomentViewerScreen({
    super.key,
    required this.groups,
    required this.initialGroup,
  });

  final List<MomentGroup> groups;
  final int initialGroup;

  @override
  ConsumerState<MomentViewerScreen> createState() => _MomentViewerScreenState();
}

class _MomentViewerScreenState extends ConsumerState<MomentViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  late int _group;
  late int _index;

  // bumps on every change so a slow image can't start a stale timer
  int _token = 0;
  bool _ready = false;
  bool _holding = false;

  MomentGroup get _g => widget.groups[_group];
  Moment get _m => _g.moments[_index];

  int _firstUnseen(MomentGroup g) {
    final seen = ref.read(seenMomentsProvider);
    final i = g.moments.indexWhere((m) => !seen.contains(m.id));
    return i == -1 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
    _index = _firstUnseen(_g);
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    if (!mounted) return;
    final token = ++_token;
    final moment = _m;
    _progress.stop();
    _progress.value = 0;
    setState(() => _ready = false);

    try {
      await precacheImage(NetworkImage(moment.imageUrl), context);
    } catch (_) {}

    if (!mounted || token != _token) return;
    ref.read(seenMomentsProvider.notifier).markSeen(moment.id);
    setState(() => _ready = true);
    if (!_holding) _progress.forward();
  }

  void _next() {
    if (!mounted) return;
    if (_index < _g.moments.length - 1) {
      setState(() => _index++);
    } else if (_group < widget.groups.length - 1) {
      setState(() {
        _group++;
        _index = _firstUnseen(_g);
      });
    } else {
      Navigator.of(context).pop();
      return;
    }
    _show();
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
    } else if (_group > 0) {
      setState(() {
        _group--;
        _index = 0;
      });
    }
    _show();
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  Future<void> _openProfile() async {
    _holding = true;
    _progress.stop();
    await openProfile(context, _g.userId);
    if (!mounted) return;
    _holding = false;
    if (_ready) _progress.forward();
  }

  Widget _bars(MomentGroup g) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => Row(
          children: [
            for (var i = 0; i < g.moments.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: i < _index
                          ? 1.0
                          : (i == _index ? _progress.value : 0.0),
                      minHeight: 3,
                      backgroundColor: Colors.white30,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(MomentGroup g, Moment m) {
    final hasPic = g.profilePicUrl != null && g.profilePicUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 60),
      child: Row(
        children: [
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openProfile,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        hasPic ? NetworkImage(g.profilePicUrl!) : null,
                    child: hasPic ? null : const Icon(Icons.person, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      g.username.isNotEmpty ? g.username : 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(_ago(m.createdAt), style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _closeButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black38,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final g = _g;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final width = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < width / 3) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) {
          _holding = true;
          _progress.stop();
        },
        onLongPressEnd: (_) {
          _holding = false;
          if (_ready) _progress.forward();
        },
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                m.imageUrl,
                key: ValueKey(m.id),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white, size: 48),
                ),
              ),
            ),
            if (!_ready)
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _bars(g),
                        const SizedBox(height: 8),
                        _header(g, m),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // top right corner, level with the avatar row
            Positioned(
              top: MediaQuery.of(context).padding.top + 13,
              right: 10,
              child: _closeButton(),
            ),
          ],
        ),
      ),
    );
  }
}