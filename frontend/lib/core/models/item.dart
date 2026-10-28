import 'source.dart';

enum ItemKind {
  article('article', 'articles'),
  episode('episode', 'episodes'),
  post('post', 'posts'),
  video('video', 'videos'),
  photo('photo', 'photos'),
  comic('comic', 'comics');

  const ItemKind(this.singular, this.plural);
  final String singular;
  final String plural;

  String count(int n) => '$n ${n == 1 ? singular : plural}';

  ItemRole get role => switch (this) {
    article || episode => ItemRole.facts,
    post || video => ItemRole.context,
    photo || comic => ItemRole.timelineOnly,
  };
}

/// What an item may do in a story.
enum ItemRole {
  /// Clusters into stories and feeds claims, what's new and disagreements.
  facts,

  /// Can join a story, never feeds claims or disagreements.
  context,

  /// Never clustered; shown as an item card.
  timelineOnly,
}

class Item {
  const Item({
    required this.id,
    required this.source,
    required this.kind,
    required this.publishedAt,
    this.title,
    this.text,
    this.url,
    this.duration,
    this.linkTitle,
    this.hasThumbnail = true,
  });

  final String id;
  final Source source;
  final ItemKind kind;
  final DateTime publishedAt;

  /// Posts usually have none.
  final String? title;

  /// An excerpt or our own summary, never the full third-party text.
  final String? text;
  final String? url;

  /// Episodes and videos.
  final Duration? duration;

  /// The page a post links to, if any.
  final String? linkTitle;
  final bool hasThumbnail;
}
