import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import 'session.dart';

/// Watchable videos from followed sources, newest first — or the demo's signed
/// out. Empty when there are none, or when the API can't be reached.
final videosProvider = FutureProvider<List<Video>>((ref) async {
  final reader = ref.watch(sessionProvider.select((s) => s.value?.account?.user.id));
  try {
    return await ref.watch(apiClientProvider).videos(demo: reader == null);
  } on ApiException {
    return const [];
  }
});
