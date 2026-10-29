import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../formatting.dart';
import 'section_header.dart';
import 'source_chip.dart';

/// New facts since the reader last read the story. Only facts, never a
/// re-summary. Sits at the top of the story page.
class WhatsNewSection extends StatefulWidget {
  const WhatsNewSection({super.key, required this.claims, this.since, this.initiallyShown = 5, this.onOpenSource});

  final List<Claim> claims;
  final DateTime? since;
  final int initiallyShown;
  final ValueChanged<Source>? onOpenSource;

  @override
  State<WhatsNewSection> createState() => _WhatsNewSectionState();
}

class _WhatsNewSectionState extends State<WhatsNewSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final since = widget.since;

    if (widget.claims.isEmpty) {
      return QuietNote(
        icon: Icons.check_circle_outline_rounded,
        title: "You're up to date",
        body: since == null
            ? 'New facts about this story will show up here.'
            : 'Nothing new ${sinceLabel(since)}. New facts will show up here.',
      );
    }

    final shown = _expanded ? widget.claims : widget.claims.take(widget.initiallyShown).toList();
    final hidden = widget.claims.length - shown.length;

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.newSignalSoft,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.newSignal.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.update_rounded,
            iconColor: c.newSignal,
            title: ['New', if (since != null) sinceLabel(since)].join(' '),
            trailing: CountPill(count: widget.claims.length, background: c.surface, foreground: c.newSignal),
          ),
          const SizedBox(height: Space.md),
          for (final claim in shown) ...[
            _ClaimRow(claim: claim, onOpenSource: widget.onOpenSource),
            if (claim != shown.last) const SizedBox(height: Space.md),
          ],
          if (hidden > 0) ...[
            const SizedBox(height: Space.sm),
            TextButton(
              onPressed: () => setState(() => _expanded = true),
              style: TextButton.styleFrom(foregroundColor: c.newSignal),
              child: Text('Show ${plural(hidden, 'more fact')}', style: t.label.copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({required this.claim, this.onOpenSource});

  final Claim claim;
  final ValueChanged<Source>? onOpenSource;

  static const _maxChips = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final extra = claim.sources.length - _maxChips;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.sm - Space.xxs),
          child: Container(
            width: Space.sm,
            height: Space.sm,
            decoration: BoxDecoration(color: c.newSignal, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(claim.text, style: t.body),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final s in claim.sources.take(_maxChips))
                    SourceChip(
                      source: s,
                      showLanguage: false,
                      onTap: onOpenSource == null ? null : () => onOpenSource!(s),
                    ),
                  if (extra > 0) Text('+$extra', style: t.caption.copyWith(color: c.textSecondary)),
                  Padding(
                    padding: const EdgeInsets.only(left: Space.xs),
                    child: Text(timeAgo(claim.reportedAt), style: t.caption.copyWith(color: c.textTertiary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
