import 'source.dart';

/// One video from a followed source: a link-out row, never played in-app.
/// OSMS keeps the publisher's page and the story it joined, never the video.
class Video {
  const Video({
    required this.id,
    required this.title,
    this.excerpt = '',
    required this.publishedAt,
    this.duration,
    required this.link,
    required this.source,
    this.storyId,
    this.storyTitle,
  });

  final String id;
  final String title;

  /// The feed's own excerpt, capped: a list row, not the video.
  final String excerpt;
  final DateTime publishedAt;

  /// The feed's stated length, when it states one; null is omitted, never guessed.
  final Duration? duration;

  /// The publisher's page to watch on.
  final String link;

  /// The channel it came from.
  final Source source;

  /// The story it joined, when clustering placed it in one.
  final String? storyId;
  final String? storyTitle;

  /// Discussed in a named story: the row links there.
  bool get hasStory => storyId != null && storyTitle != null;
}
