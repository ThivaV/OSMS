import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../formatting.dart';
import 'kind_icons.dart';
import 'section_header.dart';

/// How the story developed, oldest first, with a marker where the reader
/// last left off. Events after it are new.
class StoryTimeline extends StatelessWidget {
  const StoryTimeline({super.key, required this.events, this.lastReadAt, this.onOpen});

  final List<TimelineEvent> events;
  final DateTime? lastReadAt;

  /// Opens an event's original article. Headlines link to their publisher.
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
    final read = lastReadAt;
    final firstNew = read == null ? -1 : sorted.indexWhere((e) => e.at.isAfter(read));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(icon: Icons.timeline_rounded, title: 'How the story developed'),
        const SizedBox(height: Space.md),
        if (sorted.isEmpty)
          const QuietNote(
            icon: Icons.schedule_rounded,
            title: 'No timeline yet',
            body: 'The timeline starts when a second source picks this story up.',
          )
        else
          for (var i = 0; i < sorted.length; i++) ...[
            if (i == firstNew && i > 0) _LastReadMarker(at: read!),
            _EventRow(
              event: sorted[i],
              isNew: firstNew != -1 && i >= firstNew,
              isLast: i == sorted.length - 1,
              onOpen: onOpen,
            ),
          ],
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.isNew, required this.isLast, this.onOpen});

  final TimelineEvent event;
  final bool isNew;
  final bool isLast;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final meta = [
      '${shortDate(event.at)}, ${clockTime(event.at)}',
      plural(event.sourceCount, 'source'),
      if (isNew) 'new',
    ].join('  ·  ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: Sizes.timelineNode,
            child: Column(
              children: [
                Container(
                  width: Sizes.timelineNode,
                  height: Sizes.timelineNode,
                  decoration: BoxDecoration(
                    color: isNew ? c.newSignalSoft : c.surfaceMuted,
                    shape: BoxShape.circle,
                    border: Border.all(color: isNew ? c.newSignal : c.border),
                  ),
                  child: Icon(
                    iconForKind(event.kind),
                    size: Sizes.iconXs,
                    color: isNew ? c.newSignal : c.textSecondary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: Sizes.focusRing, color: c.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Space.lg, top: Space.xxs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (event.correctedFrom case final before?) ...[
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Corrected  ',
                            style: t.caption.copyWith(color: c.newSignal, fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: before,
                            style: t.caption.copyWith(color: c.textSecondary, decoration: TextDecoration.lineThrough),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xxs),
                  ],
                  if (event.url case final url? when onOpen != null)
                    InkWell(
                      onTap: () => onOpen!(url),
                      child: Text(
                        event.text,
                        style: t.body.copyWith(decoration: TextDecoration.underline, decorationColor: c.border),
                      ),
                    )
                  else
                    Text(event.text, style: t.body),
                  const SizedBox(height: Space.xxs),
                  Text(meta, style: t.caption.copyWith(color: isNew ? c.newSignal : c.textTertiary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastReadMarker extends StatelessWidget {
  const _LastReadMarker({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Row(
        children: [
          SizedBox(
            width: Sizes.timelineNode,
            child: Icon(Icons.bookmark_rounded, size: Sizes.iconSm, color: c.newSignal),
          ),
          const SizedBox(width: Space.md),
          Flexible(
            child: Text(
              'You last read here · ${shortDate(at)}, ${clockTime(at)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.caption.copyWith(color: c.newSignal, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Container(height: Sizes.hairline, color: c.newSignal.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}
