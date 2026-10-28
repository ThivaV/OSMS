import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../formatting.dart';
import 'section_header.dart';
import 'source_chip.dart';

/// Conflicting facts side by side, each side linked to its sources. Neutral on
/// purpose: OSMS shows that sources differ, not who is right.
class DisagreementPanel extends StatelessWidget {
  const DisagreementPanel({super.key, required this.disagreements, this.onOpenSource});

  final List<Disagreement> disagreements;
  final ValueChanged<Source>? onOpenSource;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.compare_arrows_rounded,
          title: 'Where sources disagree',
          trailing: disagreements.isEmpty ? null : CountPill(count: disagreements.length),
        ),
        const SizedBox(height: Space.md),
        if (disagreements.isEmpty)
          const QuietNote(
            icon: Icons.done_all_rounded,
            title: 'Sources agree so far',
            body: "When sources report different facts or numbers, you'll see them side by side here.",
          )
        else
          for (final d in disagreements) ...[
            _DisagreementCard(disagreement: d, onOpenSource: onOpenSource),
            if (d != disagreements.last) const SizedBox(height: Space.md),
          ],
      ],
    );
  }
}

class _DisagreementCard extends StatelessWidget {
  const _DisagreementCard({required this.disagreement, this.onOpenSource});

  final Disagreement disagreement;
  final ValueChanged<Source>? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final sides = disagreement.sides;

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(disagreement.topic, style: t.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: Space.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= Sizes.sideBySideMin && sides.length <= 3;
              final children = <Widget>[];
              for (var i = 0; i < sides.length; i++) {
                final side = _Side(side: sides[i], onOpenSource: onOpenSource);
                children.add(wide ? Expanded(child: side) : side);
                if (i < sides.length - 1) children.add(_Versus(vertical: wide));
              }
              return wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: children)
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
            },
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.side, this.onOpenSource});

  final DisagreementSide side;
  final ValueChanged<Source>? onOpenSource;

  static const _maxChips = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final extra = side.sources.length - _maxChips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(side.value, style: t.figure),
        const SizedBox(height: Space.xxs),
        Text(plural(side.sources.length, 'source'), style: t.caption.copyWith(color: c.textTertiary)),
        const SizedBox(height: Space.sm),
        Text(side.claim, style: t.bodySmall.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final s in side.sources.take(_maxChips))
              SourceChip(source: s, onTap: onOpenSource == null ? null : () => onOpenSource!(s)),
            if (extra > 0) Text('+$extra more', style: t.caption.copyWith(color: c.textSecondary)),
          ],
        ),
      ],
    );
  }
}

/// The "≠" between sides: a column gap when wide, a rule when stacked.
class _Versus extends StatelessWidget {
  const _Versus({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mark = Container(
      width: Sizes.iconXl - Space.xs,
      height: Sizes.iconXl - Space.xs,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.disagreeSoft,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      child: Text('≠', style: context.text.subhead.copyWith(color: c.disagree, height: 1)),
    );
    final labelled = Semantics(label: 'differs from', child: ExcludeSemantics(child: mark));
    if (vertical) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        child: labelled,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(padding: const EdgeInsets.symmetric(horizontal: Space.sm), child: labelled),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
