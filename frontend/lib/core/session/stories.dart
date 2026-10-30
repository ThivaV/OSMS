import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sample/sample_content.dart' as sample;
import '../api/api_client.dart';
import '../models/models.dart';
import 'session.dart';

/// What Today shows. Signed in: the reader's own stories, none until OSMS has collected
/// their sources. Signed out: the demo's stories, or its invented samples, labelled as
/// such, until the pipeline has collected real ones.
class StoriesView {
  const StoriesView({required this.stories, this.samples = false, this.unavailable = false});

  final List<Story> stories;

  /// The stories are invented samples: the demo banner says so.
  final bool samples;

  /// The API couldn't be reached; Today says so instead of claiming there's nothing.
  final bool unavailable;
}

final storiesProvider = FutureProvider<StoriesView>((ref) async {
  // Who is reading, and what they follow: a change (sign-in, onboarding again) reloads.
  final reader = ref.watch(
    sessionProvider.select((s) => (s.value?.account?.user.id, s.value?.account?.subscriptions.length)),
  );
  final api = ref.watch(apiClientProvider);
  final signedIn = reader.$1 != null;
  try {
    if (signedIn) return StoriesView(stories: await api.stories());
    final demo = await api.demoStories();
    return demo.isEmpty ? StoriesView(stories: sample.stories, samples: true) : StoriesView(stories: demo);
  } on ApiException {
    if (signedIn) return const StoriesView(stories: [], unavailable: true);
    return StoriesView(stories: sample.stories, samples: true);
  }
});
