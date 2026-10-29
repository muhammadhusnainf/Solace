import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../auth_provider.dart';
import '../feed_provider.dart';
import '../sounds.dart';
import '../likes_provider.dart';

Future<void> showCreatePostDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const CreatePostDialog(),
  );
}

class CreatePostDialog extends ConsumerStatefulWidget {
  const CreatePostDialog({super.key});

  @override
  ConsumerState<CreatePostDialog> createState() => _CreatePostDialogState();
}

final ButtonStyle _blueButton = FilledButton.styleFrom(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);

class _CreatePostDialogState extends ConsumerState<CreatePostDialog> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageMime;
  bool _isVideo = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageName = file.name;
      _imageMime = file.mimeType ?? _mimeFromName(file.name);
      _isVideo = false;
      _error = null;
    });
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageName = file.name;
      _imageMime = file.mimeType ?? _mimeFromName(file.name);
      _isVideo = true;
      _error = null;
    });
  }

  void _change() => _isVideo ? _pickVideo() : _pickImage();

  String _mimeFromName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.mp4')) return 'video/mp4';
    if (n.endsWith('.mov')) return 'video/quicktime';
    if (n.endsWith('.webm')) return 'video/webm';
    if (n.endsWith('.mkv')) return 'video/x-matroska';
    if (n.endsWith('.3gp')) return 'video/3gpp';
    if (n.endsWith('.avi')) return 'video/x-msvideo';
    return 'image/jpeg';
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null || _imageBytes == null) return;
    final text = _controller.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await api.createPost(
        userId: user.id,
        description: text,
        imageBytes: _imageBytes!,
        imageName: _imageName ?? (_isVideo ? 'video.mp4' : 'image.jpg'),
        imageMime: _imageMime,
      );
      ref.invalidate(feedProvider);
      ref.read(likesProvider.notifier).refresh();
      Sounds.success();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Post created')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ApiException ? e.message : 'Could not create post: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 512,
          minHeight: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text('Create new post',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed:
                          _submitting ? null : () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 2),
            Flexible(
              child: _imageBytes == null
                  ? _buildPicker(scheme)
                  : _buildComposer(scheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 72, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text('Select a photo or video to share',
              style: TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _pickImage,
            style: _blueButton,
            child: const Text('Select photo'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _pickVideo,
            style: _blueButton,
            child: const Text('Select video'),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: _isVideo
                    ? _videoPreview()
                    : Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting ? null : _change,
                child: Text(_isVideo ? 'Change video' : 'Change photo'),
              ),
            ),
          ],
          TextField(
            controller: _controller,
            enabled: !_submitting,
            minLines: 1,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Write a description...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_submitting && _isVideo)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Uploading video, this can take a minute',
                  textAlign: TextAlign.center),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: _blueButton,
            child: _submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post'),
          ),
        ],
      ),
    );
  }

  Widget _videoPreview() {
    final mb = (_imageBytes!.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam, color: Colors.white, size: 48),
          const SizedBox(height: 8),
          Text(
            _imageName ?? 'video',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
          Text('$mb MB', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}