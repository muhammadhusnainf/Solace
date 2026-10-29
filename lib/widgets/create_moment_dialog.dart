import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../auth_provider.dart';
import '../moments_provider.dart';
import '../profile_provider.dart';
import '../sounds.dart';

Future<void> showCreateMomentDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const CreateMomentDialog(),
  );
}

final ButtonStyle _blueButton = FilledButton.styleFrom(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);

class CreateMomentDialog extends ConsumerStatefulWidget {
  const CreateMomentDialog({super.key});

  @override
  ConsumerState<CreateMomentDialog> createState() =>
      _CreateMomentDialogState();
}

class _CreateMomentDialogState extends ConsumerState<CreateMomentDialog> {
  final _picker = ImagePicker();

  Uint8List? _bytes;
  String? _name;
  String? _mime;
  bool _submitting = false;
  String? _error;

  Future<void> _pick() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _name = file.name;
      _mime = file.mimeType ?? _mimeFromName(file.name);
      _error = null;
    });
  }

  String _mimeFromName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null || _bytes == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await api.createMoment(
        userId: user.id,
        imageBytes: _bytes!,
        imageName: _name ?? 'moment.jpg',
        imageMime: _mime,
      );
      ref.invalidate(momentsProvider);
      ref.invalidate(userProfileProvider(user.id));
      Sounds.success();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Moment shared')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ApiException ? e.message : 'Could not share moment: $e';
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
                  const Text('New moment',
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
              child: _bytes == null ? _buildPicker(scheme) : _buildPreview(),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 72, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text('Share a moment', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            'It disappears after 24 hours',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _pick,
            style: _blueButton,
            child: const Text('Select photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 360,
              color: Colors.black,
              child: Image.memory(_bytes!, fit: BoxFit.contain),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _submitting ? null : _pick,
              child: const Text('Change photo'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: _blueButton,
            child: _submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Share moment'),
          ),
        ],
      ),
    );
  }
}
