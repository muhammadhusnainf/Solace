import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../auth_provider.dart';
import '../feed_provider.dart';
import '../profile_provider.dart';
import '../cached_image.dart';

Future<void> showChangeProfilePhotoDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ChangeProfilePhotoDialog(),
  );
}

class ChangeProfilePhotoDialog extends ConsumerStatefulWidget {
  const ChangeProfilePhotoDialog({super.key});

  @override
  ConsumerState<ChangeProfilePhotoDialog> createState() =>
      _ChangeProfilePhotoDialogState();
}

class _ChangeProfilePhotoDialogState
    extends ConsumerState<ChangeProfilePhotoDialog> {
  final _picker = ImagePicker();

  Uint8List? _bytes;
  String? _name;
  String? _mime;
  bool _uploading = false;
  String? _error;

  Future<void> _choose() async {
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

  Future<void> _upload() async {
    final user = ref.read(authProvider).user;
    if (user == null || _bytes == null || _uploading) return;
    setState(() {
      _uploading = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await api.updateProfileImage(
        userId: user.id,
        imageBytes: _bytes!,
        imageName: _name ?? 'photo.jpg',
        imageMime: _mime,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e is ApiException ? e.message : 'Could not upload: $e';
      });
      return;
    }

    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    ref.invalidate(userProfileProvider(user.id));
    ref.invalidate(feedProvider);
    navigator.pop();
    messenger
        .showSnackBar(const SnackBar(content: Text('Profile photo updated')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myId = ref.watch(authProvider.select((s) => s.user?.id));
    final currentUrl = myId == null
        ? null
        : ref.watch(userProfileProvider(myId)).maybeWhen(
              data: (u) => u.profilePicUrl,
              orElse: () => null,
            );
    final hasCurrent = currentUrl != null && currentUrl.isNotEmpty;

    ImageProvider? avatar;
    if (_bytes != null) {
      avatar = MemoryImage(_bytes!);
    } else if (hasCurrent) {
      avatar = cachedImage(currentUrl);
    }

    return PopScope(
      canPop: !_uploading,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Change Profile Photo',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: avatar,
                      onBackgroundImageError:
                          avatar == null ? null : (_, _) {},
                      child: avatar == null
                          ? const Icon(Icons.person, size: 48)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton(
                          onPressed: _uploading
                              ? null
                              : (_bytes == null ? _choose : _upload),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                          child: _uploading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(_bytes == null
                                  ? 'Choose Photo'
                                  : 'Change Photo'),
                        ),
                      ),
                    ),
                    if (_bytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton(
                          onPressed: _uploading ? null : _choose,
                          child: const Text('Choose a different photo'),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.error)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              InkWell(
                onTap: _uploading ? null : () => Navigator.pop(context),
                child: const SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Center(
                    child: Text('Cancel',
                        style: TextStyle(color: Colors.red, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}