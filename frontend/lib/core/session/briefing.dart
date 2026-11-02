import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import 'session.dart';

/// The latest morning briefing: the reader's own, or the demo's signed out. Null until
/// the first is made, or when the API can't be reached.
final briefingProvider = FutureProvider<Briefing?>((ref) async {
  final reader = ref.watch(sessionProvider.select((s) => s.value?.account?.user.id));
  try {
    return await ref.watch(apiClientProvider).briefing(demo: reader == null);
  } on ApiException {
    return null;
  }
});

/// Signed in with no briefing yet: whether one is being made right now. Today asks
/// again on every refresh, so the player appears as soon as it's ready.
final briefingMakingProvider = FutureProvider<bool>((ref) async {
  final reader = ref.watch(sessionProvider.select((s) => s.value?.account?.user.id));
  if (reader == null || await ref.watch(briefingProvider.future) != null) return false;
  try {
    return await ref.watch(apiClientProvider).briefingMaking();
  } on ApiException {
    return false;
  }
});
