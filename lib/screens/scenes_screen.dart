import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models.dart';
import '../scenes_provider.dart';
import '../widgets/create_scene_dialog.dart';
import '../widgets/post_media.dart';
import '../widgets/scene_comment_sheet.dart';
import 'profile_screen.dart';
import '../cached_image.dart';

class ScenesScreen extends ConsumerStatefulWidget {
  const ScenesScreen({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<ScenesScreen> createState() => _ScenesScreenState();
}

class _ScenesScreenState extends ConsumerState<ScenesScreen> {
  final _pages = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final scene = await showCreateSceneDialog(context);
    if (scene == null || !mounted) return;
    ref.read(scenesProvider.notifier).addScene(scene);
    if (_pages.hasClients) _pages.jumpToPage(0);
    setState(() => _current = 0);
  }

  @override
  Widget build(BuildContext context) {
    final scenes = ref.watch(scenesProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: scenes.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load scenes',
                          style: TextStyle(color: Colors.white)),
                      TextButton(
                        onPressed: () => ref.invalidate(scenesProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('No scenes yet',
                          style: TextStyle(color: Colors.white70)),
                    );
                  }
                  return PageView.builder(
                    controller: _pages,
                    scrollDirection: Axis.vertical,
                    itemCount: list.length,
                    onPageChanged: (i) {
                      setState(() => _current = i);
                      if (i >= list.length - 3) {
                        ref.read(scenesProvider.notifier).loadMore();
                      }
                    },
                    itemBuilder: (context, i) => _SceneItem(
                      key: ValueKey(list[i].id),
                      scene: list[i],
                      playing: widget.active && i == _current,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _upload,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black38,
                  ),
                  child: const Icon(Icons.video_call_outlined,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneItem extends ConsumerStatefulWidget {
  const _SceneItem({super.key, required this.scene, required this.playing});

  final Scene scene;
  final bool playing;

  @override
  ConsumerState<_SceneItem> createState() => _SceneItemState();
}

class _SceneItemState extends ConsumerState<_SceneItem>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _heart = false;
  Timer? _heartTimer;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.playing) _start();
  }

  @override
  void didUpdateWidget(covariant _SceneItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !oldWidget.playing) _start();
    if (!widget.playing && oldWidget.playing) _release();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller?.pause();
    } else if (widget.playing) {
      _controller?.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartTimer?.cancel();
    _token++;
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final token = ++_token;
    _failed = false;
    final c = VideoPlayerController.networkUrl(
      Uri.parse(widget.scene.videoUrl),
    );
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(ref.read(sceneMuteProvider) ? 0 : 1);
    } catch (_) {
      await c.dispose();
      if (mounted && token == _token) setState(() => _failed = true);
      return;
    }
    if (!mounted || token != _token) {
      await c.dispose();
      return;
    }
    setState(() => _controller = c);
    await c.play();
  }

  void _release() {
    _token++;
    final c = _controller;
    if (c == null) return;
    setState(() => _controller = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  }

  void _toggle() {
    if (_failed) {
      setState(() => _failed = false);
      _start();
      return;
    }
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  void _doubleTapLike() {
    if (!widget.scene.isLiked) {
      ref.read(scenesProvider.notifier).toggleLike(widget.scene.id);
    }
    _heartTimer?.cancel();
    setState(() => _heart = true);
    _heartTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _heart = false);
    });
  }

  Future<void> _openProfile() async {
    _controller?.pause();
    await openProfile(context, widget.scene.userId);
    if (mounted && widget.playing) _controller?.play();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(sceneMuteProvider, (_, muted) {
      _controller?.setVolume(muted ? 0 : 1);
    });

    final muted = ref.watch(sceneMuteProvider);
    final scene = widget.scene;
    final c = _controller;
    final hasPic =
        scene.profilePicUrl != null && scene.profilePicUrl!.isNotEmpty;

    final commentCount = widget.playing
        ? ref.watch(sceneCommentsProvider(scene.id)).maybeWhen<int?>(
              data: (l) => l.length,
              orElse: () => null,
            )
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (c != null)
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 9 / 16,
              child: VideoPlayer(c),
            ),
          )
        else
          Image(
            image: cachedImage(scene.thumbnailUrl ?? videoPosterUrl(scene.videoUrl)),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const SizedBox(),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          onDoubleTap: _doubleTapLike,
        ),
        const IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 280,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: AnimatedScale(
              scale: _heart ? 1 : 0.5,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _heart ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 110,
                  shadows: [Shadow(blurRadius: 16, color: Colors.black38)],
                ),
              ),
            ),
          ),
        ),
        if (c != null)
          IgnorePointer(
            child: Center(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (context, value, _) => value.isPlaying
                    ? const SizedBox.shrink()
                    : const Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 72),
              ),
            ),
          ),
        if (widget.playing && c == null && !_failed)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_failed)
          const IgnorePointer(
            child: Center(
              child: Text('Could not play, tap to retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SceneAction(
                icon: scene.isLiked ? Icons.favorite : Icons.favorite_border,
                color: scene.isLiked ? Colors.redAccent : Colors.white,
                label: '${scene.likesCount}',
                onTap: () =>
                    ref.read(scenesProvider.notifier).toggleLike(scene.id),
              ),
              const SizedBox(height: 18),
              _SceneAction(
                icon: Icons.chat_bubble_outline,
                label: commentCount?.toString(),
                onTap: () => showSceneComments(context, scene.id),
              ),
              const SizedBox(height: 18),
              _SceneAction(
                icon: muted ? Icons.volume_off : Icons.volume_up,
                onTap: () => ref.read(sceneMuteProvider.notifier).toggle(),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 84,
          bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openProfile,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          hasPic ? cachedImage(scene.profilePicUrl!) : null,
                      child: hasPic ? null : const Icon(Icons.person, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '@${scene.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (scene.caption.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  scene.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        if (c != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              padding: const EdgeInsets.only(top: 8),
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
      ],
    );
  }
}

class _SceneAction extends StatelessWidget {
  const _SceneAction({
    required this.icon,
    required this.onTap,
    this.label,
    this.color = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black38,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
