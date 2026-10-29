import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../journeys_provider.dart';
import '../models.dart';
import '../picked_media.dart';
import '../sounds.dart';

Future<void> showAddMemoryDialog(BuildContext context, int journeyId) {
  return showDialog(
    context: context,
    builder: (_) => AddMemoryDialog(journeyId: journeyId),
  );
}

final ButtonStyle _blueButton = FilledButton.styleFrom(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);

class AddMemoryDialog extends ConsumerStatefulWidget {
  const AddMemoryDialog({super.key, required this.journeyId});

  final int journeyId;

  @override
  ConsumerState<AddMemoryDialog> createState() => _AddMemoryDialogState();
}

class _AddMemoryDialogState extends ConsumerState<AddMemoryDialog> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _picker = ImagePicker();

  final List<PickedMedia> _media = [];
  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickMedia() async {
    final files = await _picker.pickMultipleMedia();
    if (files.isEmpty) return;
    final picked = <PickedMedia>[];
    for (final f in files) {
      picked.add(await PickedMedia.fromFile(f));
    }
    if (!mounted) return;
    setState(() => _media.addAll(picked));
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty &&
        _content.text.trim().isEmpty &&
        _media.isEmpty) {
      setState(() => _error = 'Add a title, a reflection or some media');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await api.addJourneyEntry(
        journeyId: widget.journeyId,
        title: _title.text.trim(),
        content: _content.text.trim(),
        date: _date,
        media: _media,
      );
      ref.invalidate(journeyEntriesProvider(widget.journeyId));
      Sounds.success();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Memory saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ApiException ? e.message : 'Could not save memory: $e';
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
                  const Text('Add a memory',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add another moment to your story.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Memory title',
                        hintText: 'Give this memory a name',
                        border: border(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _submitting ? null : _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          border: border(),
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(formatDate(_date)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _content,
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Your reflection',
                        hintText: 'What do you want to remember about this day?',
                        alignLabelWithHint: true,
                        border: border(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickMedia,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(_media.isEmpty
                          ? 'Choose photos or videos'
                          : 'Add more photos or videos'),
                    ),
                    if (_media.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 84,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _media.length,
                          separatorBuilder: (context, i) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, i) => _Thumb(
                            media: _media[i],
                            onRemove: _submitting
                                ? null
                                : () => setState(() => _media.removeAt(i)),
                          ),
                        ),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    if (_submitting && _media.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('Uploading, this can take a minute',
                            textAlign: TextAlign.center),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: _blueButton,
                      child: _submitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save memory'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.media, required this.onRemove});

  final PickedMedia media;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 84,
            height: 84,
            child: media.isVideo
                ? Container(
                    color: Colors.black,
                    child: const Icon(Icons.videocam, color: Colors.white),
                  )
                : Image.memory(media.bytes, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
