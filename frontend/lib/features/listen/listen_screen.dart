import 'package:flutter/material.dart';

import '../../core/audio/episode_playback.dart';
import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/source_chip.dart';

/// Which shelf of Listen shows. One library, explicit filters — never a tab
/// per type, and never a dead one: the chip row hides what isn't here.
enum ListenFilter { all, briefings, episodes, videos }

extension ListenFilterLabel on ListenFilter {
  String get label => switch (this) {
    ListenFilter.all => 'All',
    ListenFilter.briefings => 'Briefings',
    ListenFilter.episodes => 'Episodes',
    ListenFilter.videos => 'Videos',
  };
}

/// Every audio and video in one place: today's briefing and its documents,
/// past briefings that replay, podcast episodes with their shows and stories,
/// and videos as link-out rows. Episodes without audio say so, videos without
/// a story say so; no button sits dead. One audio plays at a time — the screen
/// plays through [playback] owned above it, so leaving keeps it going.
class ListenScreen extends StatelessWidget {
  const ListenScreen({
    super.key,
    this.filter = ListenFilter.all,
    this.onFilter,
    this.latestBriefing,
    this.pastBriefings = const [],
    this.briefingLoading = false,
    this.briefingMaking = false,
    this.playingBriefingId,
    this.briefingPlaying = false,
    this.onPlayBriefing,
    this.onBackToLatest,
    this.onOpenBriefingStory,
    this.episodes = const [],
    this.shows = const [],
    this.selectedShowId,
    this.onSelectShow,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
    this.loading = false,
    this.unavailable = false,
    this.samples = false,
    this.current,
    this.playback,
    this.onPlay,
    this.onOpenStory,
    this.videos = const [],
    this.videosLoading = false,
    this.onWatchVideo,
    this.onOpenVideoStory,
    this.onAddSource,
    this.banner,
    this.bottomInset = Space.xl,
  });

  final ListenFilter filter;

  /// Switches shelves; null hides the chips, never as dead taps.
  final ValueChanged<ListenFilter>? onFilter;

  /// Today's briefing, made for this reader this morning — the hero.
  final Briefing? latestBriefing;

  /// Earlier briefings, newest first, each replayable.
  final List<Briefing> pastBriefings;
  final bool briefingLoading;

  /// Signed in with no briefing yet and one on its way: the shelf says so.
  final bool briefingMaking;

  /// The briefing on the slot, if any, and whether it plays right now.
  final String? playingBriefingId;
  final bool briefingPlaying;

  /// Starts (or pauses) a briefing. Null while nothing can play.
  final ValueChanged<Briefing>? onPlayBriefing;

  /// Returns the slot to today's briefing; hidden without it.
  final VoidCallback? onBackToLatest;

  /// Opens a briefing chapter's story — its source documents.
  final ValueChanged<String>? onOpenBriefingStory;

  final List<Episode> episodes;

  /// Every show with episodes, alphabetical — stable while paging. The chips
  /// hide for a single show; without [onSelectShow] they hide altogether,
  /// never as dead taps.
  final List<Source> shows;

  /// One show's history, or null for every show.
  final String? selectedShowId;
  final ValueChanged<String?>? onSelectShow;

  /// Older history waits behind the button; null action hides it.
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback? onLoadMore;

  final bool loading;

  /// The API couldn't be reached; says so instead of claiming there are none.
  final bool unavailable;

  /// The episodes are invented samples: the demo banner says so.
  final bool samples;

  /// The episode on the now-playing card, if any.
  final Episode? current;
  final EpisodePlayback? playback;

  /// Starts (or resumes) an episode. Null while nothing can play.
  final ValueChanged<Episode>? onPlay;

  /// Opens the story an episode joined.
  final ValueChanged<Episode>? onOpenStory;

  /// Watchable videos, newest first: rows link to the publisher's page.
  final List<Video> videos;
  final bool videosLoading;

  /// Opens the publisher's page in the browser. Null hides Watch, never dead.
  final ValueChanged<Video>? onWatchVideo;

  /// Opens the story a video joined.
  final ValueChanged<Video>? onOpenVideoStory;

  /// Offers a podcast feed; hidden without it.
  final VoidCallback? onAddSource;
  final Widget? banner;
  final double bottomInset;

  bool get _briefingsHere => latestBriefing != null || pastBriefings.isNotEmpty;
  bool get _episodesHere => episodes.isNotEmpty || shows.isNotEmpty;
  bool get _videosHere => videos.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final showEpisodes = filter == ListenFilter.all || filter == ListenFilter.episodes;
    final showBriefings = filter == ListenFilter.all || filter == ListenFilter.briefings;
    final showVideos = filter == ListenFilter.all || filter == ListenFilter.videos;
    final available = [
      if (_briefingsHere || briefingLoading || briefingMaking) ListenFilter.briefings,
      if (_episodesHere || loading) ListenFilter.episodes,
      if (_videosHere || videosLoading) ListenFilter.videos,
    ];
    final rows = _rows(episodes);
    final selectedShow = selectedShowId == null
        ? null
        : shows.where((s) => s.id == selectedShowId).firstOrNull;
    final collecting = (loading && episodes.isEmpty) || (briefingLoading && !_briefingsHere);
    return CustomScrollView(
      key: const ValueKey('listenList'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Listen', style: t.title),
                const SizedBox(height: Space.xs),
                Text(_subtitle(collecting, selectedShow), style: t.bodySmall.copyWith(color: context.colors.textSecondary)),
              ],
            ),
          ),
        ),
        if (available.length > 1 && onFilter != null)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              key: const ValueKey('typeFilter'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
              child: Row(
                children: [
                  _FilterChip(
                    label: ListenFilter.all.label,
                    selected: filter == ListenFilter.all,
                    onTap: () => onFilter!(ListenFilter.all),
                  ),
                  for (final type in available) ...[
                    const SizedBox(width: Space.sm),
                    _FilterChip(
                      label: type.label,
                      selected: filter == type,
                      onTap: () => onFilter!(type),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (showEpisodes && shows.length > 1 && onSelectShow != null)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              key: const ValueKey('showFilter'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All shows',
                    selected: selectedShowId == null,
                    onTap: () => onSelectShow!(null),
                  ),
                  for (final show in shows) ...[
                    const SizedBox(width: Space.sm),
                    _FilterChip(
                      label: show.name,
                      selected: selectedShowId == show.id,
                      onTap: () => onSelectShow!(show.id),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (banner != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
            sliver: SliverToBoxAdapter(child: banner),
          ),
        if (collecting && !_anythingHere)
          const SliverPadding(
            padding: EdgeInsets.all(Space.xl),
            sliver: SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
          )
        else if (!_anythingHere)
          SliverPadding(
            padding: const EdgeInsets.all(Space.lg),
            sliver: SliverToBoxAdapter(child: _EmptyNote(filter: filter, onAddSource: onAddSource)),
          )
        else ...[
          if (showBriefings) ...[
            if (latestBriefing != null)
              _BriefingHero(
                briefing: latestBriefing!,
                playing: playingBriefingId == latestBriefing!.id && briefingPlaying,
                pastPlaying: playingBriefingId != null && playingBriefingId != latestBriefing!.id,
                onPlay: onPlayBriefing == null ? null : () => onPlayBriefing!(latestBriefing!),
                onBackToLatest: onBackToLatest,
                onOpenStory: onOpenBriefingStory,
              ),
            if (pastBriefings.isNotEmpty) ...[
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(Space.md, Space.lg, Space.md, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(icon: Icons.history_rounded, title: 'Earlier briefings'),
                ),
              ),
              for (final past in pastBriefings)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, 0),
                  sliver: SliverToBoxAdapter(
                    child: _BriefingRow(
                      briefing: past,
                      playing: playingBriefingId == past.id && briefingPlaying,
                      onPlay: onPlayBriefing == null ? null : () => onPlayBriefing!(past),
                      onOpenStory: onOpenBriefingStory,
                    ),
                  ),
                ),
            ],
            if (latestBriefing == null && pastBriefings.isEmpty && !briefingLoading)
              SliverPadding(
                padding: const EdgeInsets.all(Space.lg),
                sliver: SliverToBoxAdapter(
                  child: QuietNote(
                    icon: Icons.wb_twilight_rounded,
                    title: briefingMaking ? 'Your first briefing is on its way' : 'No briefings yet',
                    body: briefingMaking
                        ? 'Every morning at 07:00, OSMS reads you the stories that changed overnight, one chapter per story.'
                        : 'Your morning briefing waits here once OSMS has made the first one.',
                  ),
                ),
              ),
          ],
          if (showEpisodes) ...[
            if (unavailable)
              const SliverPadding(
                padding: EdgeInsets.all(Space.lg),
                sliver: SliverToBoxAdapter(
                  child: QuietNote(
                    icon: Icons.cloud_off_rounded,
                    title: 'Your episodes didn’t load',
                    body: 'OSMS couldn’t reach its server. Listen tries again every minute.',
                  ),
                ),
              )
            else if (episodes.isEmpty && !loading)
              SliverPadding(
                padding: const EdgeInsets.all(Space.lg),
                sliver: SliverToBoxAdapter(
                  child: QuietNote(
                    icon: Icons.podcasts_rounded,
                    title: 'No episodes yet',
                    body: 'Follow a podcast feed and its episodes wait for you here, playable, '
                        'each linked to the story it joined.',
                    action: onAddSource == null
                        ? null
                        : FilledButton.icon(
                            onPressed: onAddSource,
                            icon: const Icon(Icons.add_rounded, size: Sizes.iconMd),
                            label: const Text('Add a podcast'),
                          ),
                  ),
                ),
              )
            else ...[
              if (current != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
                  sliver: SliverToBoxAdapter(
                    child: _NowPlaying(episode: current!, playback: playback, onPlay: onPlay),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, hasMore ? Space.sm : 0),
                sliver: SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    return switch (row) {
                      _ShowHeader(:final show, :final count) => _ShowHeaderRow(show: show, count: count),
                      _EpisodeRow(:final episode) => _EpisodeCard(
                        episode: episode,
                        playing: current?.id == episode.id,
                        playback: current?.id == episode.id ? playback : null,
                        onPlay: onPlay == null ? null : () => onPlay!(episode),
                        onOpenStory: episode.hasStory && onOpenStory != null ? () => onOpenStory!(episode) : null,
                      ),
                    };
                  },
                ),
              ),
              if (hasMore)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
                  sliver: SliverToBoxAdapter(
                    child: loadingMore
                        ? const Center(
                            child: SizedBox.square(
                              dimension: Sizes.iconLg,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: onLoadMore,
                            icon: const Icon(Icons.history_rounded, size: Sizes.iconMd),
                            label: const Text('Show older episodes'),
                          ),
                  ),
                ),
            ],
          ],
          if (showVideos) ...[
            if (videos.isNotEmpty) ...[
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(Space.md, Space.lg, Space.md, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(icon: Icons.videocam_outlined, title: 'Videos'),
                ),
              ),
              for (final video in videos)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, 0),
                  sliver: SliverToBoxAdapter(
                    child: _VideoCard(
                      video: video,
                      onWatch: onWatchVideo == null ? null : () => onWatchVideo!(video),
                      onOpenStory: video.hasStory && onOpenVideoStory != null ? () => onOpenVideoStory!(video) : null,
                    ),
                  ),
                ),
            ] else if (!videosLoading)
              const SliverPadding(
                padding: EdgeInsets.all(Space.lg),
                sliver: SliverToBoxAdapter(
                  child: QuietNote(
                    icon: Icons.videocam_outlined,
                    title: 'No videos yet',
                    body: 'Videos from your followed channels wait here, each with its story when it joined one.',
                  ),
                ),
              ),
          ],
          SliverPadding(padding: EdgeInsets.only(bottom: bottomInset)),
        ],
      ],
    );
  }

  bool get _anythingHere => _briefingsHere || episodes.isNotEmpty || _videosHere || unavailable;

  String _subtitle(bool collecting, Source? selectedShow) {
    if (collecting) return 'Collecting…';
    final parts = <String>[
      if (_briefingsHere && (filter == ListenFilter.all || filter == ListenFilter.briefings))
        plural(pastBriefings.length + (latestBriefing == null ? 0 : 1), 'briefing'),
      if (_episodesHere && (filter == ListenFilter.all || filter == ListenFilter.episodes))
        selectedShow != null
            ? '${plural(episodes.length, 'episode', 'episodes')} from ${selectedShow.name}'
            : '${plural(episodes.length, 'episode', 'episodes')} from ${plural(shows.length, 'show')}',
      if (_videosHere && (filter == ListenFilter.all || filter == ListenFilter.videos))
        plural(videos.length, 'video'),
    ];
    if (parts.isEmpty) return 'Your audio and video, newest first';
    return parts.join('  ·  ');
  }
}

/// The hub holds nothing at all yet: one honest note, never three shrugs.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.filter, this.onAddSource});

  final ListenFilter filter;
  final VoidCallback? onAddSource;

  @override
  Widget build(BuildContext context) {
    return QuietNote(
      icon: Icons.headphones_outlined,
      title: switch (filter) {
        ListenFilter.briefings => 'No briefings yet',
        ListenFilter.episodes => 'No episodes yet',
        ListenFilter.videos => 'No videos yet',
        ListenFilter.all => 'Nothing to listen to yet',
      },
      body: switch (filter) {
        ListenFilter.briefings => 'Your morning briefing waits here once OSMS has made the first one.',
        ListenFilter.episodes => 'Follow a podcast feed and its episodes wait for you here, playable, '
            'each linked to the story it joined.',
        ListenFilter.videos => 'Videos from your followed channels wait here, each with its story when it joined one.',
        ListenFilter.all => 'Follow a podcast feed or a channel and your audio and video wait for you here.',
      },
      action: onAddSource == null || filter == ListenFilter.videos || filter == ListenFilter.briefings
          ? null
          : FilledButton.icon(
              onPressed: onAddSource,
              icon: const Icon(Icons.add_rounded, size: Sizes.iconMd),
              label: const Text('Add a podcast'),
            ),
    );
  }
}

/// One filter chip: fill plus bold when selected, never colour alone. The row
/// hides instead when there is nothing to choose between.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: selected ? c.accent : c.border),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.label.copyWith(
                color: selected ? c.text : c.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's briefing, made for this reader: play it, read what it covers, and
/// open each chapter's story — the source documents behind the narration.
class _BriefingHero extends StatelessWidget {
  const _BriefingHero({
    required this.briefing,
    required this.playing,
    required this.pastPlaying,
    required this.onPlay,
    required this.onBackToLatest,
    required this.onOpenStory,
  });

  final Briefing briefing;
  final bool playing;

  /// A past briefing holds the slot: the hero offers the way back to today.
  final bool pastPlaying;
  final VoidCallback? onPlay;
  final VoidCallback? onBackToLatest;
  final ValueChanged<String>? onOpenStory;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final playable = briefing.audioUrl != null && onPlay != null;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, 0),
      sliver: SliverToBoxAdapter(
        child: Container(
          key: const ValueKey('briefingHero'),
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: c.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(icon: Icons.wb_twilight_rounded, title: 'Morning briefing'),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  _PlayButton(
                    playing: playing,
                    enabled: playable,
                    disabledMessage: 'No audio for this briefing yet',
                    onPressed: playable ? onPlay! : null,
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${shortDate(briefing.date)}  ·  ${plural(briefing.chapters.length, 'story', 'stories')}  ·  '
                          '${durationLabel(briefing.duration)}',
                          style: t.caption.copyWith(color: c.textTertiary, fontWeight: FontWeight.w600),
                        ),
                        if (!playable)
                          Text('No audio yet', style: t.caption.copyWith(color: c.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
              if (pastPlaying && onBackToLatest != null) ...[
                const SizedBox(height: Space.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onBackToLatest,
                    icon: const Icon(Icons.today_outlined, size: Sizes.iconMd),
                    label: const Text('Back to today’s briefing'),
                  ),
                ),
              ],
              if (onOpenStory != null) ...[
                const SizedBox(height: Space.xs),
                for (final chapter in briefing.chapters)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => onOpenStory!(chapter.storyId),
                      icon: const Icon(Icons.forum_outlined, size: Sizes.iconMd),
                      label: Text(
                        chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One past briefing: its date, length and stories, replayable through the
/// same slot as today's.
class _BriefingRow extends StatelessWidget {
  const _BriefingRow({
    required this.briefing,
    required this.playing,
    required this.onPlay,
    required this.onOpenStory,
  });

  final Briefing briefing;
  final bool playing;
  final VoidCallback? onPlay;
  final ValueChanged<String>? onOpenStory;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final playable = briefing.audioUrl != null && onPlay != null;
    return Container(
      key: ValueKey('pastBriefing-${briefing.id}'),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: playing ? c.accent : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlayButton(
                playing: playing,
                enabled: playable,
                disabledMessage: 'No audio for this briefing yet',
                onPressed: playable ? onPlay! : null,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortDate(briefing.date),
                      style: t.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      '${plural(briefing.chapters.length, 'story', 'stories')}  ·  '
                      '${durationLabel(briefing.duration)}',
                      style: t.caption.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onOpenStory != null) ...[
            const SizedBox(height: Space.xs),
            for (final chapter in briefing.chapters)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onOpenStory!(chapter.storyId),
                  icon: const Icon(Icons.forum_outlined, size: Sizes.iconMd),
                  label: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One video: its channel, what it is about, a Watch button for the
/// publisher's page, and its story when it joined one. Videos without a story
/// say so instead of offering a dead link.
class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onWatch, required this.onOpenStory});

  final Video video;
  final VoidCallback? onWatch;
  final VoidCallback? onOpenStory;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: onWatch == null ? 'The publisher’s page is unavailable' : 'Watch on ${video.source.name}',
                child: Material(
                  color: onWatch == null ? c.surfaceSunken : c.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onWatch,
                    child: SizedBox(
                      width: Sizes.playButton,
                      height: Sizes.playButton,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: onWatch == null ? c.textTertiary : c.onAccent,
                        size: Sizes.iconXl,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(video.title, style: t.body.copyWith(fontWeight: FontWeight.w600)),
                    if (video.excerpt.isNotEmpty) ...[
                      const SizedBox(height: Space.xxs),
                      Text(
                        video.excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    ],
                    const SizedBox(height: Space.xs),
                    Text(
                      [
                        video.source.name,
                        if (video.duration != null) durationLabel(video.duration!),
                        timeAgo(video.publishedAt),
                      ].join('  ·  '),
                      style: t.caption.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onOpenStory != null && video.hasStory) ...[
            const SizedBox(height: Space.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenStory,
                icon: const Icon(Icons.forum_outlined, size: Sizes.iconMd),
                label: Text(
                  'Discussed in ${video.storyTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: Space.xs),
            Text('Not part of a story yet', style: t.caption.copyWith(color: c.textTertiary)),
          ],
        ],
      ),
    );
  }
}

int _compareNewest(DateTime? a, DateTime? b) {
  // Undated episodes sort last, stably.
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

/// Episodes grouped by show, show order by newest episode.
List<List<Episode>> _byShow(List<Episode> episodes) {
  final groups = <String, List<Episode>>{};
  for (final e in episodes) {
    groups.putIfAbsent(e.show.id, () => []).add(e);
  }
  final lists = groups.values.toList();
  for (final list in lists) {
    list.sort((a, b) => _compareNewest(a.publishedAt, b.publishedAt));
  }
  lists.sort((a, b) => _compareNewest(a.first.publishedAt, b.first.publishedAt));
  return lists;
}

sealed class _Row {
  const _Row();
}

class _ShowHeader extends _Row {
  const _ShowHeader(this.show, this.count);
  final Source show;
  final int count;
}

class _EpisodeRow extends _Row {
  const _EpisodeRow(this.episode);
  final Episode episode;
}

List<_Row> _rows(List<Episode> episodes) => [
  for (final group in _byShow(episodes)) ...[_ShowHeader(group.first.show, group.length), ...group.map(_EpisodeRow.new)],
];

class _ShowHeaderRow extends StatelessWidget {
  const _ShowHeaderRow({required this.show, required this.count});
  final Source show;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, Space.xs),
      child: Row(
        children: [
          SourceAvatar(source: show, size: Sizes.avatarSm),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              show.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.label.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${plural(count, 'episode', 'episodes')} · ${show.type.label}',
            style: t.caption.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.playing,
    required this.playback,
    required this.onPlay,
    required this.onOpenStory,
  });

  final Episode episode;
  final bool playing;
  final EpisodePlayback? playback;
  final VoidCallback? onPlay;
  final VoidCallback? onOpenStory;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final playback = this.playback;
    final playable = episode.audioUrl != null && onPlay != null;
    return Container(
      key: ValueKey('episode-${episode.id}'),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: playing ? c.accent : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (playback != null)
                ValueListenableBuilder(
                  valueListenable: playback.state,
                  builder: (_, state, _) => _PlayButton(
                    playing: state.playing,
                    enabled: playable,
                    onPressed: playable ? onPlay! : null,
                  ),
                )
              else
                _PlayButton(playing: playing, enabled: playable, onPressed: playable ? onPlay! : null),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(episode.title, style: t.body.copyWith(fontWeight: FontWeight.w600)),
                    if (episode.excerpt.isNotEmpty) ...[
                      const SizedBox(height: Space.xxs),
                      Text(
                        episode.excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    ],
                    const SizedBox(height: Space.xs),
                    Text(
                      [
                        if (episode.duration != null) durationLabel(episode.duration!),
                        if (episode.publishedAt != null) timeAgo(episode.publishedAt!),
                        if (!playable) 'No audio yet',
                      ].join('  ·  '),
                      style: t.caption.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (playing && playback != null) ...[
            const SizedBox(height: Space.sm),
            _Progress(playback: playback, total: episode.duration),
          ],
          if (onOpenStory != null && episode.hasStory) ...[
            const SizedBox(height: Space.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenStory,
                icon: const Icon(Icons.forum_outlined, size: Sizes.iconMd),
                label: Text(
                  'Discussed in ${episode.storyTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.enabled,
    required this.onPressed,
    this.disabledMessage = 'No audio for this episode yet',
  });

  final bool playing;
  final bool enabled;
  final VoidCallback? onPressed;

  /// Disabled buttons explain themselves; callers name their own medium.
  final String disabledMessage;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: !enabled ? disabledMessage : (playing ? 'Pause' : 'Play'),
      child: Material(
        color: enabled ? c.accent : c.surfaceSunken,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            width: Sizes.playButton,
            height: Sizes.playButton,
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: enabled ? c.onAccent : c.textTertiary,
              size: Sizes.iconXl,
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.playback, required this.total});
  final EpisodePlayback playback;
  final Duration? total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder(
      valueListenable: playback.state,
      builder: (context, state, _) {
        final total = this.total;
        final progress = total == null || total.inMilliseconds == 0
            ? 0.0
            : (state.position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: Sizes.rail,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: progress,
                onChanged: total == null ? null : (v) => playback.seek(total * v),
              ),
            ),
            Row(
              children: [
                Text(playerTime(state.position), style: context.text.caption.copyWith(color: c.textSecondary)),
                const Spacer(),
                if (state.failed)
                  Text(
                    'The audio isn’t available right now.',
                    style: context.text.caption.copyWith(color: c.textSecondary),
                  )
                else if (total != null)
                  Text('−${playerTime(total - state.position)}', style: context.text.caption.copyWith(color: c.textSecondary)),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The episode on top: show, title, play and progress. Without [playback]
/// (samples, Widgetbook) the bar is simulated.
class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.episode, required this.playback, required this.onPlay});

  final Episode episode;
  final EpisodePlayback? playback;
  final ValueChanged<Episode>? onPlay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final playback = this.playback;
    final playable = episode.audioUrl != null && onPlay != null;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.podcasts_rounded, title: 'Now playing'),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              if (playback != null)
                ValueListenableBuilder(
                  valueListenable: playback.state,
                  builder: (_, state, _) => _PlayButton(
                    playing: state.playing,
                    enabled: playable,
                    onPressed: playable ? () => onPlay!(episode) : null,
                  ),
                )
              else
                _PlayButton(playing: false, enabled: playable, onPressed: playable ? () => onPlay!(episode) : null),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.show.name,
                      style: t.caption.copyWith(color: c.textTertiary, fontWeight: FontWeight.w600),
                    ),
                    Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.subhead),
                  ],
                ),
              ),
            ],
          ),
          if (playable && playback != null) ...[
            const SizedBox(height: Space.sm),
            _Progress(playback: playback, total: episode.duration),
          ],
        ],
      ),
    );
  }
}
