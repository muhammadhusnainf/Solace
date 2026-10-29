import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../models.dart';
import '../picked_media.dart';
import '../sounds.dart';

const int _maxBytes = 100 * 1024 * 1024;

Future<Scene?> showCreateSceneDialog(BuildContext context) {
  return showDialog<Scene>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const CreateSceneDialog(),
  );
}

final ButtonStyle _primaryButton = FilledButton.styleFrom(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);

class CreateSceneDialog extends StatefulWidget {
  const CreateSceneDialog({super.key});

  @override
  State<CreateSceneDialog> createState() => _CreateSceneDialogState();
}

class _CreateSceneDialogState extends State<CreateSceneDialog> {
  final _picker = ImagePicker();
  final _caption = TextEditingController();

  PickedMedia? _video;
  bool _reading = false;
  bool _submitting = false;
  double _progress = 0;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_reading || _submitting) return;
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      if (await file.length() > _maxBytes) {
        if (!mounted) return;
        setState(() {
          _reading = false;
          _error = 'That video is larger than 100 MB';
        });
        return;
      }
      final bytes = await file.readAsBytes();
      var mime = file.mimeType ?? mimeFromName(file.name);
      if (!mime.startsWith('video/')) mime = 'video/mp4';
      if (!mounted) return;
      setState(() {
        _video = PickedMedia(
          bytes: bytes,
          name: file.name,
          mime: mime,
          isVideo: true,
        );
        _reading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _error = 'Could not read that video';
      });
    }
  }

  Future<void> _submit() async {
    final video = _video;
    if (video == null || _submitting) return;
    setState(() {
      _submitting = true;
      _progress = 0;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final scene = await api.createScene(
        video: video,
        caption: _caption.text.trim(),
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = sent / total);
        },
      );
      Sounds.success();
      navigator.pop(scene);
      messenger.showSnackBar(const SnackBar(content: Text('Scene published')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ApiException ? e.message : 'Could not publish scene';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_submitting,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 512,
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
                    const Text('New scene',
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
                child: _video == null ? _buildPicker(scheme) : _buildForm(scheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPicker(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined,
              size: 72, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text('Share a scene', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            'Videos up to 100 MB',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _reading ? null : _pick,
            style: _primaryButton,
            child: _reading
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurface,
                    ),
                  )
                : const Text('Select video'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ColorScheme scheme) {
    final video = _video!;
    final mb = (video.bytes.length / (1024 * 1024)).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.movie_outlined, color: scheme.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$mb MB',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _submitting ? null : _pick,
              child: const Text('Change video'),
            ),
          ),
          TextField(
            controller: _caption,
            enabled: !_submitting,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'What makes this moment special?',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (_submitting)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _progress >= 1 ? null : _progress,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _progress >= 1
                        ? 'Processing video'
                        : 'Uploading ${(_progress * 100).round()}%',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          FilledButton(
            onPressed: _submit,
            style: _primaryButton,
            child: _submitting
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Text('Share scene'),
          ),
        ],
      ),
    );
  }
}
