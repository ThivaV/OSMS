import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sample/sample_content.dart' as sample;
import '../api/api_client.dart';
import '../models/models.dart';
import 'session.dart';

/// What Podcasts shows. Signed in: the reader's own episodes, none until their
/// podcast feeds are fetched. Signed out: playable samples, labelled as such,
/// until the pipeline has collected real ones.
class PodcastsState {
  const PodcastsState({
    this.episodes = const [],
    this.shows = const [],
    this.nextCursor,
    this.selectedShowId,
    this.loading = true,
    this.loadingMore = false,
    this.samples = false,
    this.unavailable = false,
  });

  /// Episodes loaded so far, newest first, within the selected show if any.
  final List<Episode> episodes;

  /// Every show with episodes, alphabetical — stable while paging.
  final List<Source> shows;

  /// Cursor for the next history page; null when history ends here.
  final String? nextCursor;
  bool get hasMore => nextCursor != null;

  /// One show's history, or null for every show.
  final String? selectedShowId;

  final bool loading;
  final bool loadingMore;

  /// The episodes are invented samples: the demo banner says so.
  final bool samples;

  /// The API couldn't be reached; Podcasts says so instead of claiming none.
  final bool unavailable;
}

/// The whole playlist, a page at a time. `Show older episodes` appends the
/// next page; picking a show resets to its first page. A refresh (sign-in,
/// onboarding again, the minute tick) rebuilds from page one.
class PodcastsController extends Notifier<PodcastsState> {
  var _generation = 0;

  @override
  PodcastsState build() {
    // Who is reading, and what they follow: a change reloads from page one.
    final reader = ref.watch(
      sessionProvider.select((s) => (s.value?.account?.user.id, s.value?.account?.subscriptions.length)),
    );
    final api = ref.watch(apiClientProvider);
    final generation = ++_generation;
    _firstPage(api, signedIn: reader.$1 != null, generation: generation);
    return const PodcastsState();
  }

  Future<void> _firstPage(ApiClient api, {required bool signedIn, required int generation}) async {
    try {
      if (signedIn) {
        final page = await api.episodes();
        _set(
          generation,
          PodcastsState(episodes: page.episodes, shows: page.shows, nextCursor: page.nextCursor, loading: false),
        );
      } else {
        final page = await api.episodes(demo: true);
        if (page.episodes.isEmpty && page.shows.isEmpty) {
          _set(generation, _samples(null));
        } else {
          _set(
            generation,
            PodcastsState(episodes: page.episodes, shows: page.shows, nextCursor: page.nextCursor, loading: false),
          );
        }
      }
    } on ApiException {
      _set(
        generation,
        signedIn
            ? const PodcastsState(loading: false, unavailable: true)
            : _samples(null),
      );
    }
  }

  /// Samples paginate nowhere; the filter still works over them.
  PodcastsState _samples(String? showId) {
    final all = sample.sampleEpisodes;
    final shows = _sampleShows(all);
    final episodes = showId == null ? all : [for (final e in all) if (e.show.id == showId) e];
    return PodcastsState(episodes: episodes, shows: shows, selectedShowId: showId, loading: false, samples: true);
  }

  static List<Source> _sampleShows(List<Episode> episodes) {
    final seen = <String, Source>{};
    for (final e in episodes) {
      seen.putIfAbsent(e.show.id, () => e.show);
    }
    final shows = seen.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return shows;
  }

  void _set(int generation, PodcastsState next) {
    if (generation == _generation && ref.mounted) state = next;
  }

  /// Appends the next history page. Concurrent taps collapse into one load.
  Future<void> loadMore() async {
    final current = state;
    final cursor = current.nextCursor;
    // Samples never carry a cursor, so history always ends on page one there.
    if (current.loading || current.loadingMore || cursor == null || current.samples) return;
    final api = ref.read(apiClientProvider);
    final signedIn = ref.read(sessionProvider).value?.account?.user.id != null;
    final generation = _generation;
    state = _copy(current, loadingMore: true);
    try {
      final page = await api.episodes(demo: !signedIn, cursor: cursor, sourceId: current.selectedShowId);
      if (generation != _generation || !ref.mounted) return;
      state = _copy(
        current,
        loadingMore: false,
        episodes: [...current.episodes, ...page.episodes],
        nextCursor: page.nextCursor,
      );
    } on ApiException {
      if (generation == _generation && ref.mounted) state = _copy(current, loadingMore: false);
    }
  }

  /// Narrows to one show's history (or back to every show), from page one.
  Future<void> selectShow(String? showId) async {
    final current = state;
    if (current.selectedShowId == showId || current.loading) return;
    if (current.samples) {
      state = _samples(showId);
      return;
    }
    final api = ref.read(apiClientProvider);
    final signedIn = ref.read(sessionProvider).value?.account?.user.id != null;
    final generation = ++_generation;
    state = _copy(current, loading: true, loadingMore: false, selectedShowId: showId);
    try {
      final page = await api.episodes(demo: !signedIn, sourceId: showId);
      if (generation != _generation || !ref.mounted) return;
      state = PodcastsState(
        episodes: page.episodes,
        shows: current.shows,
        nextCursor: page.nextCursor,
        selectedShowId: showId,
        loading: false,
        unavailable: current.unavailable,
      );
    } on ApiException {
      if (generation == _generation && ref.mounted) state = _copy(current, loading: false);
    }
  }

  PodcastsState _copy(
    PodcastsState current, {
    bool? loading,
    bool? loadingMore,
    List<Episode>? episodes,
    String? nextCursor,
    String? selectedShowId,
  }) => PodcastsState(
    episodes: episodes ?? current.episodes,
    shows: current.shows,
    nextCursor: nextCursor,
    selectedShowId: selectedShowId ?? current.selectedShowId,
    loading: loading ?? current.loading,
    loadingMore: loadingMore ?? current.loadingMore,
    samples: current.samples,
    unavailable: current.unavailable,
  );
}

final episodesProvider = NotifierProvider<PodcastsController, PodcastsState>(PodcastsController.new);
