import 'source.dart';

/// One podcast episode: playable, sourced, and linked to its story when
/// clustering placed it in one. Audio stays a link: playback streams from the
/// publisher, never from OSMS.
class Episode {
  const Episode({
    required this.id,
    required this.title,
    this.excerpt = '',
    this.publishedAt,
    this.duration,
    this.audioUrl,
    required this.show,
    this.storyId,
    this.storyTitle,
  });

  final String id;
  final String title;

  /// The feed's own excerpt, capped: a list row, not the episode.
  final String excerpt;
  final DateTime? publishedAt;
  final Duration? duration;

  /// The enclosure to stream. Null: the feed gave no safe one, and the row
  /// says so instead of offering a dead Play button.
  final String? audioUrl;

  /// The podcast it came from.
  final Source show;

  /// The story it joined, when clustering placed it in one.
  final String? storyId;
  final String? storyTitle;

  /// Discussed in a named story: the row links there.
  bool get hasStory => storyId != null && storyTitle != null;
}
