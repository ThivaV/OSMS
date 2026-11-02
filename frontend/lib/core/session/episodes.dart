import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sample/sample_content.dart' as sample;
import '../api/api_client.dart';
import '../models/models.dart';
import 'session.dart';

/// What Podcasts shows. Signed in: the reader's own episodes, none until their
/// podcast feeds are fetched. Signed out: playable samples, labelled as such,
/// until the pipeline has collected real ones.
class EpisodesView {
  const EpisodesView({required this.episodes, this.samples = false, this.unavailable = false});

  final List<Episode> episodes;

  /// The episodes are invented samples: the demo banner says so.
  final bool samples;

  /// The API couldn't be reached; Podcasts says so instead of claiming none.
  final bool unavailable;
}

final episodesProvider = FutureProvider<EpisodesView>((ref) async {
  final reader = ref.watch(
    sessionProvider.select((s) => (s.value?.account?.user.id, s.value?.account?.subscriptions.length)),
  );
  final api = ref.watch(apiClientProvider);
  final signedIn = reader.$1 != null;
  try {
    if (signedIn) return EpisodesView(episodes: await api.episodes());
    final demo = await api.episodes(demo: true);
    return demo.isEmpty ? EpisodesView(episodes: sample.sampleEpisodes, samples: true) : EpisodesView(episodes: demo);
  } on ApiException {
    if (signedIn) return const EpisodesView(episodes: [], unavailable: true);
    return EpisodesView(episodes: sample.sampleEpisodes, samples: true);
  }
});
