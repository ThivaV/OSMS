import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/glass.dart';
import '../../shared/widgets/section_header.dart';

const _speeds = [1.0, 1.25, 1.5, 2.0, 0.75];

/// The morning briefing: one chapter per story. The progress bar is split
/// into one segment per chapter. Playback is simulated until audio exists.
class BriefingPlayer extends StatefulWidget {
  const BriefingPlayer({super.key, required this.briefing, this.initialChapter = 0, this.initialProgress = 0.35});

  /// Null until the first briefing has been made.
  final Briefing? briefing;
  final int initialChapter;

  /// Progress through the current chapter, 0–1.
  final double initialProgress;

  @override
  State<BriefingPlayer> createState() => _BriefingPlayerState();
}

class _BriefingPlayerState extends State<BriefingPlayer> {
  late int _chapter = widget.initialChapter;
  late double _progress = widget.initialProgress;
  bool _playing = false;
  int _speed = 0;

  void _jump(int chapter) => setState(() {
    _chapter = chapter.clamp(0, widget.briefing!.chapters.length - 1);
    _progress = 0;
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final briefing = widget.briefing;

    if (briefing == null || briefing.chapters.isEmpty) {
      return const QuietNote(
        icon: Icons.wb_twilight_rounded,
        title: 'Your first briefing is on its way',
        body: 'Every morning at 07:00, OSMS reads you the stories that changed overnight, one chapter per story.',
      );
    }

    final chapters = briefing.chapters;
    final current = chapters[_chapter];
    final before = chapters.take(_chapter).fold(Duration.zero, (sum, ch) => sum + ch.duration);
    final elapsed = before + current.duration * _progress;
    final remaining = briefing.duration - elapsed;

    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(icon: Icons.wb_twilight_rounded, title: 'Morning briefing'),
          const SizedBox(height: Space.xxs),
          Text(
            '${shortDate(briefing.date)}  ·  ${plural(chapters.length, 'story', 'stories')}  ·  '
            '${durationLabel(briefing.duration)}',
            style: t.caption.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: Space.lg),
          Text('Chapter ${_chapter + 1} of ${chapters.length}', style: t.caption.copyWith(color: c.textTertiary)),
          const SizedBox(height: Space.xs),
          Text(current.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headline),
          const SizedBox(height: Space.lg),
          _ChapterBar(chapters: chapters, current: _chapter, progress: _progress, onChapter: _jump),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Text(playerTime(elapsed), style: t.caption.copyWith(color: c.textSecondary)),
              const Spacer(),
              Text('−${playerTime(remaining)}', style: t.caption.copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Back 15 seconds',
                onPressed: () => setState(() => _progress = (_progress - 0.1).clamp(0, 1)),
                icon: const Icon(Icons.replay_rounded),
              ),
              IconButton(
                tooltip: 'Previous story',
                onPressed: _chapter == 0 ? null : () => _jump(_chapter - 1),
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              const SizedBox(width: Space.sm),
              _PlayButton(playing: _playing, onPressed: () => setState(() => _playing = !_playing)),
              const SizedBox(width: Space.sm),
              IconButton(
                tooltip: 'Next story',
                onPressed: _chapter == chapters.length - 1 ? null : () => _jump(_chapter + 1),
                icon: const Icon(Icons.skip_next_rounded),
              ),
              TextButton(
                onPressed: () => setState(() => _speed = (_speed + 1) % _speeds.length),
                style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                child: Text('${_speeds[_speed]}×'.replaceAll('.0×', '×')),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          const Divider(),
          const SizedBox(height: Space.sm),
          for (var i = 0; i < chapters.length; i++)
            _ChapterRow(
              index: i,
              chapter: chapters[i],
              current: i == _chapter,
              playing: i == _chapter && _playing,
              onTap: () => _jump(i),
            ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: playing ? 'Pause' : 'Play',
      child: Material(
        color: c.accent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: Sizes.playButton,
            height: Sizes.playButton,
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: c.onAccent,
              size: Sizes.iconXl,
            ),
          ),
        ),
      ),
    );
  }
}

/// One segment per chapter, sized by its length. Tap a segment to jump.
class _ChapterBar extends StatelessWidget {
  const _ChapterBar({required this.chapters, required this.current, required this.progress, required this.onChapter});

  final List<BriefingChapter> chapters;
  final int current;
  final double progress;
  final ValueChanged<int> onChapter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Chapter ${current + 1} of ${chapters.length}',
      child: Row(
        children: [
          for (var i = 0; i < chapters.length; i++) ...[
            Expanded(
              flex: chapters[i].duration.inSeconds.clamp(1, 1 << 20),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChapter(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: SizedBox(
                      height: i == current ? Sizes.rail + Space.xxs : Sizes.rail,
                      child: LinearProgressIndicator(
                        value: i < current ? 1 : (i == current ? progress : 0),
                        color: c.accent,
                        backgroundColor: c.border,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (i < chapters.length - 1) const SizedBox(width: Space.xxs),
          ],
        ],
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.index,
    required this.chapter,
    required this.current,
    required this.playing,
    required this.onTap,
  });

  final int index;
  final BriefingChapter chapter;
  final bool current;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      button: true,
      selected: current,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm + Space.xxs),
          decoration: BoxDecoration(
            color: current ? c.accentSoft : null,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              SizedBox(
                width: Space.xl,
                child: playing
                    ? Icon(Icons.graphic_eq_rounded, size: Sizes.iconMd, color: c.accent)
                    : Text('${index + 1}', style: t.label.copyWith(color: c.textTertiary)),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  chapter.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(fontWeight: current ? FontWeight.w600 : null),
                ),
              ),
              if (chapter.newFactCount > 0) ...[
                const SizedBox(width: Space.sm),
                Text(
                  '${chapter.newFactCount} new',
                  style: t.caption.copyWith(color: c.newSignal, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(width: Space.md),
              Text(durationLabel(chapter.duration), style: t.caption.copyWith(color: c.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact bar for the sidebar or the bottom of the screen.
class BriefingMiniPlayer extends StatelessWidget {
  const BriefingMiniPlayer({super.key, required this.briefing, this.chapter = 0, this.progress = 0.35, this.onOpen});

  final Briefing briefing;
  final int chapter;
  final double progress;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final current = briefing.chapters.isEmpty ? null : briefing.chapters[chapter];
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Row(
                children: [
                  Container(
                    width: Sizes.avatarLg - Space.xs,
                    height: Sizes.avatarLg - Space.xs,
                    decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                    child: Icon(Icons.play_arrow_rounded, color: c.onAccent, size: Sizes.iconLg),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Briefing · ${durationLabel(briefing.duration)}',
                          style: t.caption.copyWith(color: c.textTertiary),
                        ),
                        Text(
                          current?.title ?? 'Ready at 07:00',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.label,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: progress,
              minHeight: Sizes.focusRing,
              color: c.accent,
              backgroundColor: c.border,
            ),
          ],
        ),
      ),
    );
  }
}

/// The floating player: a glass capsule over the bottom of the story list (and
/// above the tab bar on phones). Title, exact time left, play and skip.
class BriefingFloatingBar extends StatefulWidget {
  const BriefingFloatingBar({super.key, required this.briefing, this.chapter = 0, this.progress = 0.35, this.onOpen});

  final Briefing briefing;
  final int chapter;
  final double progress;
  final VoidCallback? onOpen;

  static const height = 60.0;

  @override
  State<BriefingFloatingBar> createState() => _BriefingFloatingBarState();
}

class _BriefingFloatingBarState extends State<BriefingFloatingBar> {
  late int _chapter = widget.chapter;
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final chapters = widget.briefing.chapters;
    if (chapters.isEmpty) return const SizedBox.shrink();
    final current = chapters[_chapter.clamp(0, chapters.length - 1)];
    final before = chapters.take(_chapter).fold(Duration.zero, (sum, ch) => sum + ch.duration);
    final left = widget.briefing.duration - (before + current.duration * widget.progress);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Sizes.sheetMaxWidth),
      child: GlassSurface(
        padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.xs, Space.sm),
        child: SizedBox(
          height: BriefingFloatingBar.height - Space.sm * 2,
          child: Row(
            children: [
              Tooltip(
                message: _playing ? 'Pause' : 'Play',
                child: Material(
                  color: c.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _playing = !_playing),
                    child: SizedBox.square(
                      dimension: BriefingFloatingBar.height - Space.sm * 2,
                      child: Icon(
                        _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: c.onAccent,
                        size: Sizes.iconLg,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: InkWell(
                  onTap: widget.onOpen,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.label.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Briefing · ${playerTime(left)} left',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next story',
                visualDensity: VisualDensity.compact,
                onPressed: _chapter >= chapters.length - 1 ? null : () => setState(() => _chapter++),
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
