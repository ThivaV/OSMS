import 'package:flutter/material.dart';

import '../../core/models/models.dart';

/// Generic glyphs only: never a platform's logo.
IconData iconForKind(ItemKind kind) => switch (kind) {
  ItemKind.article => Icons.article_outlined,
  ItemKind.episode => Icons.podcasts_rounded,
  ItemKind.post => Icons.chat_bubble_outline_rounded,
  ItemKind.video => Icons.smart_display_outlined,
  ItemKind.photo => Icons.photo_outlined,
  ItemKind.comic => Icons.auto_stories_outlined,
};

IconData iconForSourceType(SourceType type) => switch (type) {
  SourceType.feed => Icons.rss_feed_rounded,
  SourceType.newsletter => Icons.mail_outline_rounded,
  SourceType.podcast || SourceType.soundcloud => Icons.podcasts_rounded,
  SourceType.youtube => Icons.smart_display_outlined,
  SourceType.mastodon || SourceType.bluesky || SourceType.microblog => Icons.chat_bubble_outline_rounded,
  SourceType.reddit => Icons.forum_outlined,
  SourceType.pixelfed || SourceType.glass || SourceType.flickr => Icons.photo_camera_outlined,
  SourceType.comic => Icons.auto_stories_outlined,
};
