import 'package:flutter/material.dart';
import '../cached_image.dart';

Future<void> openImageViewer(BuildContext context, String url) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ImageViewerPage(url: url)),
  );
}

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({super.key, required this.url});

  final String url;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final _transform = TransformationController();
  Offset _tapAt = Offset.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        -_tapAt.dx * (scale - 1),
        -_tapAt.dy * (scale - 1),
        0,
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GestureDetector(
        onDoubleTapDown: (d) => _tapAt = d.localPosition,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image(
              image: cachedImage(widget.url),
              fit: BoxFit.contain,
              frameBuilder: (context, child, frame, loadedSync) =>
                  frame == null && !loadedSync
                      ? const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white),
                        )
                      : child,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}