import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../journeys_provider.dart';
import '../models.dart';
import '../picked_media.dart';
import '../sounds.dart';

Future<Journey?> showCreateJourneyDialog(BuildContext context) {
  return showDialog<Journey>(
    context: context,
    builder: (_) => const CreateJourneyDialog(),
  );
}

final ButtonStyle _blueButton = FilledButton.styleFrom(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);

class CreateJourneyDialog extends ConsumerStatefulWidget {
  const CreateJourneyDialog({super.key});

  @override
  ConsumerState<CreateJourneyDialog> createState() =>
      _CreateJourneyDialogState();
}

class _CreateJourneyDialogState extends ConsumerState<CreateJourneyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();

  PickedMedia? _cover;
  String _visibility = 'private';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final media = await PickedMedia.fromFile(file);
    if (!mounted) return;
    setState(() => _cover = media);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final journey = await api.createJourney(
        title: _title.text.trim(),
        description: _description.text.trim(),
        visibility: _visibility,
        cover: _cover,
      );
      ref.invalidate(journeysProvider);
      Sounds.success();
      navigator.pop(journey);
      messenger.showSnackBar(const SnackBar(content: Text('Journey created')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ApiException ? e.message : 'Could not create journey: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    OutlineInputBorder border() =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12));

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
                  const Text('Begin a new chapter',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Give your Journey a name. You can add memories as you go.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _title,
                        maxLength: 100,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Journey title',
                          hintText: 'e.g. My University Years',
                          border: border(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _description,
                        maxLength: 500,
                        minLines: 3,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'What is this chapter about?',
                          alignLabelWithHint: true,
                          border: border(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_cover == null)
                        OutlinedButton.icon(
                          onPressed: _submitting ? null : _pickCover,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Choose a cover image'),
                        )
                      else ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 150,
                            child: Image.memory(_cover!.bytes,
                                fit: BoxFit.cover),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _submitting ? null : _pickCover,
                              child: const Text('Change'),
                            ),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => setState(() => _cover = null),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _visibility,
                        decoration: InputDecoration(
                          labelText: 'Who can see this Journey?',
                          border: border(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'private', child: Text('Only me')),
                          DropdownMenuItem(
                              value: 'public', child: Text('Public')),
                          DropdownMenuItem(
                              value: 'followers', child: Text('Followers')),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _visibility = v ?? 'private'),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: _blueButton,
                        child: _submitting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Create Journey'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
