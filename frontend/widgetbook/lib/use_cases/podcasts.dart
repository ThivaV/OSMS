import 'package:flutter/material.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/features/podcasts/podcasts_screen.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;

@widgetbook.UseCase(name: 'Normal', type: PodcastsScreen, path: '[Podcasts]')
Widget podcastsNormal(BuildContext context) => Material(
  child: PodcastsScreen(
    episodes: fx.sampleEpisodes,
    current: fx.sampleEpisodes.first,
    onPlay: (_) {},
    onOpenStory: (_) {},
    onAddSource: () {},
  ),
);

@widgetbook.UseCase(name: 'Empty', type: PodcastsScreen, path: '[Podcasts]')
Widget podcastsEmpty(BuildContext context) =>
    Material(child: PodcastsScreen(episodes: const [], onAddSource: () {}));

@widgetbook.UseCase(name: 'Extreme content', type: PodcastsScreen, path: '[Podcasts]')
Widget podcastsExtreme(BuildContext context) => Material(
  child: PodcastsScreen(
    episodes: [
      Episode(
        id: 'x1',
        title:
            'A very long episode title that keeps going past any reasonable card width, with “quotes”, em-dashes — and more, testing the two-line clamp and ellipsis under pressure',
        excerpt:
            'An equally long excerpt that describes the episode in far more words than any list row should ever show, '
            'so the clamp can prove itself across light and dark, phone and desktop.',
        show: fx.gradientHour,
      ),
      Episode(
        id: 'x2',
        title: 'Undated, untimed, unsummarised',
        show: fx.soundwavesDaily,
        storyId: 'halcyon-2',
        storyTitle:
            'An unusually long story title standing in for the discussed-in link, to prove it ellipsises instead of pushing the row off the screen',
      ),
    ],
    onPlay: (_) {},
    onOpenStory: (_) {},
  ),
);
