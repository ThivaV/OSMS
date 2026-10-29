/// Where a source's items come from. The platform name is shown as text;
/// its logo never is.
enum SourceType {
  feed('Feed'),
  arxiv('arXiv'),
  newsletter('Newsletter'),
  podcast('Podcast'),
  soundcloud('SoundCloud'),
  youtube('YouTube'),
  mastodon('Mastodon'),
  bluesky('Bluesky'),
  reddit('Reddit'),
  microblog('Micro.blog'),
  pixelfed('Pixelfed'),
  glass('Glass'),
  flickr('Flickr'),
  comic('Comic strip');

  const SourceType(this.label);
  final String label;
}

class Source {
  const Source({
    required this.id,
    required this.name,
    required this.type,
    required this.language,
    this.handle,
    this.url,
    this.followed = false,
  });

  final String id;
  final String name;
  final SourceType type;

  /// ISO 639-1 code: `en`, `da`, `ta`, ...
  final String language;

  /// `@name@instance`, `@name.domain`, `r/name`, ... for social sources.
  final String? handle;
  final String? url;

  /// Whether the signed-in user follows it. Stories mark the user's sources.
  final bool followed;
}
