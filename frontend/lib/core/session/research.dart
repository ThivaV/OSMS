import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import 'session.dart';

/// New arXiv papers for the signed-in reader's research interests; none signed out.
final researchProvider = FutureProvider<List<Item>>((ref) async {
  final reader = ref.watch(sessionProvider.select((s) => (s.value?.account?.user.id, s.value?.account?.interests.length)));
  if (reader.$1 == null) return const [];
  try {
    return await ref.watch(apiClientProvider).research();
  } on ApiException {
    return const [];
  }
});
