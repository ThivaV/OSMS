import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import 'session.dart';

/// What Saved shows. Signed in: the reader's saved stories, kept by OSMS so every
/// device sees them. Signed out: the demo's, kept only until the page closes.
class SavedState {
  const SavedState({this.stories = const [], this.loading = true, this.unavailable = false});

  /// Newest saved first.
  final List<Story> stories;
  final bool loading;

  /// The API couldn't be reached; Saved says so instead of claiming there's nothing.
  final bool unavailable;

  bool contains(String storyId) => stories.any((s) => s.id == storyId);
}

/// Saving shows at once and is sent after; if OSMS refuses, the change is undone and
/// the caller is told.
class SavedController extends Notifier<SavedState> {
  var _generation = 0;

  @override
  SavedState build() {
    final reader = ref.watch(sessionProvider.select((s) => s.value?.account?.user.id));
    final generation = ++_generation;
    if (reader == null) return const SavedState(loading: false);
    _load(ref.watch(apiClientProvider), generation);
    return const SavedState();
  }

  Future<void> _load(ApiClient api, int generation) async {
    SavedState next;
    try {
      next = SavedState(stories: await api.savedStories(), loading: false);
    } on ApiException {
      next = const SavedState(loading: false, unavailable: true);
    }
    if (generation == _generation && ref.mounted) state = next;
  }

  /// Saves [story], or unsaves it when it is saved. Throws [ApiException] when OSMS
  /// refused; the list is back as it was by then.
  Future<void> toggle(Story story) async {
    final before = state;
    final saving = !before.contains(story.id);
    state = SavedState(
      stories: saving
          ? [story, ...before.stories]
          : [
              for (final s in before.stories)
                if (s.id != story.id) s,
            ],
      loading: false,
      unavailable: before.unavailable,
    );
    if (ref.read(sessionProvider).value?.signedIn != true) return;
    final api = ref.read(apiClientProvider);
    try {
      await (saving ? api.saveStory(story.id) : api.unsaveStory(story.id));
    } on ApiException {
      if (ref.mounted) state = before;
      rethrow;
    }
  }
}

final savedProvider = NotifierProvider<SavedController, SavedState>(SavedController.new);
