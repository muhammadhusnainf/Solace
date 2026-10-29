
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'models.dart';

final feedProvider = FutureProvider<List<Post>>((ref) async {
  return api.getFeed();
}, retry: (_, _) => null);
