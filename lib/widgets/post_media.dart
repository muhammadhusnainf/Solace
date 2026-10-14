import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models.dart';

// cloudinary gives a still frame if you swap the extension to jpg
String videoPosterUrl(String url) {
  final dot = url.lastIndexOf('.');
  final slash = url.lastIndexOf('/');
  if (dot <= slash) return url;
  return '${url.substring(0, dot)}.jpg';
}

class PostMedia extends StatelessWidget {
  const PostMedia({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    if (post.isVideo) return _VideoView(url: post.imageUrl!);
    return Image.network(
      post.imageUrl!,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const SizedBox(
        height: 120,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class PostThumb extends StatelessWidget {
  const PostThumb({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!post.isVideo) {
      return Image.network(
        post.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: scheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          videoPosterUrl(post.imageUrl!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: scheme.surfaceContainerHighest,
            child: const Icon(Icons.videocam_outlined),
          ),
        ),
        const Positioned(
          top: 6,
          right: 6,
          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 22),
        ),
      ],
    );
  }
}

class _VideoView extends StatefulWidget {
  const _VideoView({required this.url});

  final String url;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  // only one video plays at a time in a scrolling feed
  static _VideoViewState? _active;

  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;
  bool _muted = false;
  int _skipSeconds = 0;
  Timer? _skipTimer;

  @override
  void dispose() {
    _skipTimer?.cancel();
    if (_active == this) _active = null;
    _controller?.dispose();
    super.dispose();
  }

  void _pause() => _controller?.pause();

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });

    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      await c.setLooping(true);
    } catch (_) {
      await c.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }

    if (!mounted) {
      await c.dispose();
      return;
    }

    _active?._pause();
    _active = this;
    setState(() {
      _controller = c;
      _loading = false;
    });
    await c.play();
  }

  void _toggle() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null) return;
    setState(() => _muted = !_muted);
    c.setVolume(_muted ? 0 : 1);
  }

  void _skip(int seconds) {
    final c = _controller;
    if (c == null) return;
    final total = c.value.duration;
    var target = c.value.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;
    c.seekTo(target);

    _skipTimer?.cancel();
    setState(() => _skipSeconds = seconds);
    _skipTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _skipSeconds = 0);
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return _poster();

    final ratio = c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;

    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(c),
          // left half skips back, right half skips forward on double tap
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  onDoubleTap: () => _skip(-10),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  onDoubleTap: () => _skip(10),
                ),
              ),
            ],
          ),
          IgnorePointer(
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, value, _) => value.isPlaying
                  ? const SizedBox.shrink()
                  : const Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 64),
            ),
          ),
          if (_skipSeconds != 0)
            Align(
              alignment: _skipSeconds < 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _skipSeconds < 0 ? '10 sec back' : '10 sec forward',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: _toggleMute,
              icon: Icon(
                _muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
              ),
              style: IconButton.styleFrom(backgroundColor: Colors.black38),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, value, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(value.position),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                        Text(_fmt(value.duration),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                  VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    padding: const EdgeInsets.only(top: 6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _poster() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _start,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            videoPosterUrl(widget.url),
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 220,
              width: double.infinity,
              color: Colors.black87,
            ),
          ),
          if (_loading)
            const CircularProgressIndicator(color: Colors.white)
          else if (_failed)
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 40),
                SizedBox(height: 4),
                Text('Could not play, tap to retry',
                    style: TextStyle(color: Colors.white)),
              ],
            )
          else
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
        ],
      ),
    );
  }
}