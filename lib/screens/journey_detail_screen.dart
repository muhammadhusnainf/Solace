import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../journeys_provider.dart';
import '../models.dart';
import '../picked_media.dart';
import '../widgets/add_memory_dialog.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/delete_badge.dart';
import '../widgets/image_viewer.dart';
import '../widgets/post_media.dart';
import 'journeys_screen.dart';
import '../cached_image.dart';

Future<void> openJourney(BuildContext context, Journey journey) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => JourneyDetailScreen(journey: journey)),
  );
}

final ButtonStyle _blueButton = FilledButton.styleFrom(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);

class JourneyDetailScreen extends ConsumerWidget {
  const JourneyDetailScreen({super.key, required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final entries = ref.watch(journeyEntriesProvider(journey.id));
    final hasCover = journey.coverUrl != null && journey.coverUrl!.isNotEmpty;
    final count = entries.maybeWhen<int?>(data: (l) => l.length, orElse: () => null);

    return Scaffold(
      appBar: AppBar(title: Text(journey.title, maxLines: 1)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(journeyEntriesProvider(journey.id));
          await ref.read(journeyEntriesProvider(journey.id).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (hasCover)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image(
                    image: cachedImage(journey.coverUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: scheme.surfaceContainerHighest),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              journey.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            if (journey.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                journey.description,
                style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                JourneyPill(
                  icon: visibilityIcon(journey.visibility),
                  label: journey.visibilityLabel,
                ),
                JourneyPill(
                  icon: journey.isCompleted
                      ? Icons.check_circle_outline
                      : Icons.timelapse,
                  label: journey.isCompleted ? 'Completed' : 'In progress',
                ),
                if (count != null)
                  JourneyPill(
                    icon: Icons.menu_book_outlined,
                    label: count == 1 ? '1 memory' : '$count memories',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showAddMemoryDialog(context, journey.id),
                style: _blueButton,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add memory'),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'YOUR STORY, UNFOLDING',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Journey timeline',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            entries.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Failed to load memories: $err')),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.menu_book_outlined,
                            size: 34, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        const Text('Your story starts here',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          'Add your first memory to begin this Journey.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < list.length; i++)
                      _EntryTile(
                        entry: list[i],
                        journeyId: journey.id,
                        last: i == list.length - 1,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends ConsumerStatefulWidget {
  const _EntryTile({
    required this.entry,
    required this.journeyId,
    required this.last,
  });

  final JourneyEntry entry;
  final int journeyId;
  final bool last;

  @override
  ConsumerState<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends ConsumerState<_EntryTile> {
  bool _uploading = false;
  bool _removing = false;

  bool get _editing => _removing && widget.entry.media.isNotEmpty;

  Future<void> _addMedia() async {
    final files = await ImagePicker().pickMultipleMedia();
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final picked = <PickedMedia>[];
      for (final f in files) {
        picked.add(await PickedMedia.fromFile(f));
      }
      await api.addEntryMedia(
        journeyId: widget.journeyId,
        entryId: widget.entry.id,
        media: picked,
      );
      ref.invalidate(journeyEntriesProvider(widget.journeyId));
      messenger.showSnackBar(const SnackBar(content: Text('Media added')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not add media: $e',
          ),
        ),
      );
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _deleteMemory() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Delete memory',
      message: 'This memory and all of its photos and videos will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.deleteEntry(
        journeyId: widget.journeyId,
        entryId: widget.entry.id,
      );
      ref.invalidate(journeyEntriesProvider(widget.journeyId));
      messenger.showSnackBar(const SnackBar(content: Text('Memory deleted')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not delete memory: $e',
          ),
        ),
      );
    }
  }

  Future<void> _removeMedia(JourneyMedia m) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmDialog(
      context,
      title: m.isVideo ? 'Remove video' : 'Remove photo',
      message: 'This ${m.isVideo ? 'video' : 'photo'} will be removed.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.deleteEntryMedia(
        journeyId: widget.journeyId,
        entryId: widget.entry.id,
        mediaId: m.id,
      );
      ref.invalidate(journeyEntriesProvider(widget.journeyId));
      messenger.showSnackBar(const SnackBar(content: Text('Removed')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not remove media: $e',
          ),
        ),
      );
    }
  }

  Widget _withRemove(JourneyMedia m, Widget child, {bool left = false}) {
    if (!_editing) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          top: 6,
          left: left ? 6 : null,
          right: left ? null : 6,
          child: DeleteBadge(onTap: () => _removeMedia(m)),
        ),
      ],
    );
  }

  Widget _imageTile(String url, {BoxFit fit = BoxFit.cover}) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => openImageViewer(context, url),
      child: Image(
        image: cachedImage(url),
        width: double.infinity,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: scheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  Widget _media() {
    final images = widget.entry.media.where((m) => !m.isVideo).toList();
    final videos = widget.entry.media.where((m) => m.isVideo).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (images.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: _withRemove(images.first, _imageTile(images.first.url)),
              ),
            ),
          ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final m in images)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _withRemove(m, _imageTile(m.url)),
                  ),
              ],
            ),
          ),
        for (final m in videos)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _withRemove(m, UrlVideo(url: m.url), left: true),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final count = entry.media.length;
    final editing = _editing;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        decoration: BoxDecoration(
          border: widget.last
              ? null
              : Border(left: BorderSide(color: scheme.outlineVariant, width: 2)),
        ),
        padding: EdgeInsets.only(left: 18, bottom: widget.last ? 0 : 24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -25,
              top: 11,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatDate(entry.entryDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.more_vert,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      onSelected: (v) {
                        if (v == 'media') setState(() => _removing = !_removing);
                        if (v == 'delete') _deleteMemory();
                      },
                      itemBuilder: (_) => [
                        if (entry.media.isNotEmpty)
                          PopupMenuItem(
                            value: 'media',
                            child: Row(
                              children: [
                                Icon(Icons.photo_library_outlined,
                                    size: 20, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 12),
                                Text(editing
                                    ? 'Done removing'
                                    : 'Remove photos or videos'),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded,
                                  size: 20, color: scheme.error),
                              const SizedBox(width: 12),
                              Text(
                                'Delete memory',
                                style: TextStyle(color: scheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (entry.title.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
                if (entry.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(entry.content, style: const TextStyle(fontSize: 15)),
                ],
                _media(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _addMedia,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _uploading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: Text(_uploading ? 'Uploading' : 'Add media'),
                    ),
                    const Spacer(),
                    if (editing)
                      TextButton(
                        onPressed: () => setState(() => _removing = false),
                        child: const Text('Done'),
                      )
                    else if (count > 0)
                      Text(
                        count == 1 ? '1 attachment' : '$count attachments',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
