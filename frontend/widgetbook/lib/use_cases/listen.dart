import 'package:flutter/material.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/features/listen/listen_screen.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;

const _shows = [fx.gradientHour, fx.soundwavesDaily, fx.tinkerersAudio];

List<Video> get _videos => [
  Video(
    id: 'v1',
    title: 'Selene-3 sends its first images',
    excerpt: 'The landing, live from mission control.',
    publishedAt: DateTime(2026, 10, 31, 8, 30),
    duration: const Duration(minutes: 10, seconds: 24),
    link: 'https://launchpad.example/v1',
    source: fx.launchpadLens,
    storyId: fx.halcyon.id,
    storyTitle: fx.halcyon.title,
  ),
  Video(
    id: 'v2',
    title: 'A walk around the pad',
    publishedAt: DateTime(2026, 10, 30, 18, 5),
    link: 'https://launchpad.example/v0',
    source: fx.launchpadLens,
  ),
];

@widgetbook.UseCase(name: 'Normal', type: ListenScreen, path: '[Listen]')
Widget listenNormal(BuildContext context) => Material(
  child: ListenScreen(
    onFilter: (_) {},
    latestBriefing: fx.briefing,
    pastBriefings: const [],
    onPlayBriefing: (_) {},
    onOpenBriefingStory: (_) {},
    episodes: fx.sampleEpisodes,
    shows: _shows,
    onSelectShow: (_) {},
    hasMore: true,
    onLoadMore: () {},
    current: fx.sampleEpisodes.first,
    onPlay: (_) {},
    onOpenStory: (_) {},
    videos: _videos,
    onWatchVideo: (_) {},
    onOpenVideoStory: (_) {},
    onAddSource: () {},
  ),
);

@widgetbook.UseCase(name: 'Filtered to one show', type: ListenScreen, path: '[Listen]')
Widget listenFiltered(BuildContext context) => Material(
  child: ListenScreen(
    filter: ListenFilter.episodes,
    onFilter: (_) {},
    episodes: [fx.sampleEpisodes.first],
    shows: _shows,
    selectedShowId: fx.gradientHour.id,
    onSelectShow: (_) {},
    onPlay: (_) {},
    onOpenStory: (_) {},
  ),
);

@widgetbook.UseCase(name: 'Loading older episodes', type: ListenScreen, path: '[Listen]')
Widget listenLoadingMore(BuildContext context) => Material(
  child: ListenScreen(
    filter: ListenFilter.episodes,
    onFilter: (_) {},
    episodes: fx.sampleEpisodes,
    shows: _shows,
    onSelectShow: (_) {},
    hasMore: true,
    loadingMore: true,
    onPlay: (_) {},
    onOpenStory: (_) {},
  ),
);

@widgetbook.UseCase(name: 'Briefings', type: ListenScreen, path: '[Listen]')
Widget listenBriefings(BuildContext context) => Material(
  child: ListenScreen(
    filter: ListenFilter.briefings,
    onFilter: (_) {},
    latestBriefing: fx.briefing,
    pastBriefings: [fx.briefing],
    playingBriefingId: fx.briefing.id,
    briefingPlaying: true,
    onPlayBriefing: (_) {},
    onBackToLatest: () {},
    onOpenBriefingStory: (_) {},
  ),
);

@widgetbook.UseCase(name: 'Videos', type: ListenScreen, path: '[Listen]')
Widget listenVideos(BuildContext context) => Material(
  child: ListenScreen(
    filter: ListenFilter.videos,
    onFilter: (_) {},
    videos: _videos,
    onWatchVideo: (_) {},
    onOpenVideoStory: (_) {},
  ),
);

@widgetbook.UseCase(name: 'Empty', type: ListenScreen, path: '[Listen]')
Widget listenEmpty(BuildContext context) => Material(child: ListenScreen(episodes: const [], onAddSource: () {}));

@widgetbook.UseCase(name: 'Extreme content', type: ListenScreen, path: '[Listen]')
Widget listenExtreme(BuildContext context) => Material(
  child: ListenScreen(
    filter: ListenFilter.episodes,
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
