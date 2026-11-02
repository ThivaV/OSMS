import 'package:flutter/material.dart';

import '../../core/audio/episode_playback.dart';
import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/source_chip.dart';

/// Every podcast in one place: play any episode, see its show, and follow it
/// to the story it joined. Episodes without audio say so; the button never
/// sits dead. One audio plays at a time — the screen plays through [playback]
/// owned above it, so leaving keeps the episode going.
class PodcastsScreen extends StatelessWidget {
  const PodcastsScreen({
    super.key,
    required this.episodes,
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
    this.onAddSource,
    this.banner,
    this.bottomInset = Space.xl,
  });

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

  /// Offers a podcast feed; hidden without it.
  final VoidCallback? onAddSource;
  final Widget? banner;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final rows = _rows(episodes);
    final selectedShow = selectedShowId == null
        ? null
        : shows.where((s) => s.id == selectedShowId).firstOrNull;
    return CustomScrollView(
      key: const ValueKey('podcastsList'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Podcasts', style: t.title),
                const SizedBox(height: Space.xs),
                Text(
                  loading
                      ? 'Collecting episodes…'
                      : episodes.isEmpty
                      ? 'Your shows, playable'
                      : selectedShow != null
                      ? '${plural(episodes.length, 'episode', 'episodes')} from ${selectedShow.name}'
                      : '${plural(episodes.length, 'episode', 'episodes')} from ${plural(shows.length, 'show')}',
                  style: t.bodySmall.copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        if (shows.length > 1 && onSelectShow != null)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              key: const ValueKey('showFilter'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
              child: Row(
                children: [
                  _ShowChip(
                    label: 'All shows',
                    selected: selectedShowId == null,
                    onTap: () => onSelectShow!(null),
                  ),
                  for (final show in shows) ...[
                    const SizedBox(width: Space.sm),
                    _ShowChip(
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
        if (episodes.isEmpty && loading)
          const SliverPadding(
            padding: EdgeInsets.all(Space.xl),
            sliver: SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
          )
        else if (unavailable)
          const SliverPadding(
            padding: EdgeInsets.all(Space.lg),
            sliver: SliverToBoxAdapter(
              child: QuietNote(
                icon: Icons.cloud_off_rounded,
                title: 'Your podcasts didn’t load',
                body: 'OSMS couldn’t reach its server. Podcasts tries again every minute.',
              ),
            ),
          )
        else if (episodes.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(Space.lg),
            sliver: SliverToBoxAdapter(
              child: QuietNote(
                icon: Icons.podcasts_rounded,
                title: 'No podcasts yet',
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
            padding: EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, hasMore ? Space.sm : bottomInset),
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
              padding: EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, bottomInset),
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
    );
  }
}

/// One show's chip: fill plus bold when selected, never colour alone. The row
/// hides instead when there is nothing to choose between.
class _ShowChip extends StatelessWidget {
  const _ShowChip({required this.label, required this.selected, required this.onTap});

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
                  builder: (_, state, _) =>
                      _PlayButton(playing: state.playing, enabled: playable, onPressed: playable ? onPlay! : null),
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
  const _PlayButton({required this.playing, required this.enabled, required this.onPressed});

  final bool playing;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: !enabled ? 'No audio for this episode yet' : (playing ? 'Pause' : 'Play'),
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
