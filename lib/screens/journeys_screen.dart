import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../journeys_provider.dart';
import '../models.dart';
import '../widgets/create_journey_dialog.dart';
import 'journey_detail_screen.dart';
import '../cached_image.dart';

final ButtonStyle _blueButton = FilledButton.styleFrom(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);

IconData visibilityIcon(String visibility) {
  switch (visibility) {
    case 'public':
      return Icons.public;
    case 'followers':
      return Icons.group_outlined;
    default:
      return Icons.lock_outline;
  }
}

class JourneysScreen extends ConsumerStatefulWidget {
  const JourneysScreen({super.key});

  @override
  ConsumerState<JourneysScreen> createState() => _JourneysScreenState();
}

class _JourneysScreenState extends ConsumerState<JourneysScreen> {
  final _search = TextEditingController();
  String _filter = 'ongoing';
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await showCreateJourneyDialog(context);
    if (created != null && mounted) openJourney(context, created);
  }

  List<Journey> _visible(List<Journey> all) {
    final q = _query.trim().toLowerCase();
    return all.where((j) {
      if (_filter == 'ongoing' && j.isCompleted) return false;
      if (_filter == 'completed' && !j.isCompleted) return false;
      if (q.isEmpty) return true;
      return j.title.toLowerCase().contains(q) ||
          j.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final journeys = ref.watch(journeysProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(journeysProvider);
        await ref.read(journeysProvider.future);
      },
      child: journeys.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load journeys: $err')),
        data: (all) {
          final shown = _visible(all);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your chapters',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _create,
                    style: _blueButton,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Your personal collection of life\'s experiences.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'ongoing', label: Text('Ongoing')),
                    ButtonSegment(value: 'completed', label: Text('Completed')),
                    ButtonSegment(value: 'all', label: Text('All')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search your Journeys',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (all.isEmpty)
                _EmptyState(onCreate: _create)
              else if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: Text('No journeys match.')),
                )
              else
                for (final j in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _JourneyCard(journey: j),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.menu_book_outlined,
                size: 30, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your next chapter starts here',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a Journey to collect the memories, experiences and moments that matter to you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onCreate,
            style: _blueButton,
            child: const Text('Create your first Journey'),
          ),
        ],
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasCover = journey.coverUrl != null && journey.coverUrl!.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => openJourney(context, journey),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: hasCover
                  ? Image(
                    image: cachedImage(journey.coverUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _CoverPlaceholder(color: scheme.surfaceContainerHighest),
                    )
                  : _CoverPlaceholder(color: scheme.surfaceContainerHighest),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    journey.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  if (journey.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      journey.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      JourneyPill(
                        icon: visibilityIcon(journey.visibility),
                        label: journey.visibilityLabel,
                      ),
                      const SizedBox(width: 8),
                      JourneyPill(
                        icon: journey.isCompleted
                            ? Icons.check_circle_outline
                            : Icons.timelapse,
                        label: journey.isCompleted ? 'Completed' : 'Ongoing',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: Icon(
        Icons.menu_book_outlined,
        size: 44,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class JourneyPill extends StatelessWidget {
  const JourneyPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
