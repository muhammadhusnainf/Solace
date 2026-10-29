import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'auth_provider.dart';
import 'models.dart';

final journeysProvider = FutureProvider<List<Journey>>((ref) {
  ref.watch(authProvider.select((s) => s.user?.id));
  return api.getJourneys();
});

final journeyEntriesProvider = FutureProvider.autoDispose
    .family<List<JourneyEntry>, int>((ref, journeyId) async {
  final entries = await api.getJourneyEntries(journeyId);
  entries.sort((a, b) {
    final byDate = b.entryDate.compareTo(a.entryDate);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  });
  return entries;
});
