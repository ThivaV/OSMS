import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../formatting.dart';
import 'hover_lift.dart';
import 'kind_icons.dart';
import 'source_chip.dart';
import 'story_visual.dart';

/// One item outside a story. Every kind shares the same source line on top;
/// the body suits the kind. Videos open on the platform.
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, this.onTap, this.onPlay});

  final Item item;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HoverLift(
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SourceLine(item: item),
                const SizedBox(height: Space.md),
                ...switch (item.kind) {
                  ItemKind.article => _article(context),
                  ItemKind.paper => _paper(context),
                  ItemKind.post => _post(context),
                  ItemKind.video => _video(context),
                  ItemKind.episode => _episode(context),
                  ItemKind.photo || ItemKind.comic => _picture(context),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _article(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return [
      if (item.title != null) Text(item.title!, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.headlineSmall),
      if (item.title != null && item.text != null) const SizedBox(height: Space.xs),
      if (item.text != null)
        Text(item.text!, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodySmall.copyWith(color: c.textSecondary)),
      if (item.title == null && item.text == null) const _NoPreview(),
    ];
  }

  /// A paper: title, authors, abstract, categories, why it's here, and links that
  /// open on arXiv. OSMS never hosts the PDF.
  List<Widget> _paper(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final authors = item.authors;
    final byline = authors.isEmpty
        ? null
        : authors.length <= 3
        ? authors.join(', ')
        : '${authors.take(3).join(', ')} et al. (${authors.length} authors)';
    final reasons = [
      for (final term in item.matchedTerms) 'Matches “$term”',
      if (item.matchedTerms.isEmpty && item.matchedByMeaning) 'Related to your interests',
    ];
    return [
      if (item.title != null) Text(item.title!, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.headlineSmall),
      if (byline != null) ...[
        const SizedBox(height: Space.xs),
        Text(byline, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.textSecondary)),
      ],
      if (item.text != null) ...[
        const SizedBox(height: Space.sm),
        Text(item.text!, maxLines: 4, overflow: TextOverflow.ellipsis, style: t.bodySmall.copyWith(color: c.textSecondary)),
      ],
      if (item.title == null && item.text == null) const _NoPreview(),
      if (item.categories.isNotEmpty || reasons.isNotEmpty) ...[
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final reason in reasons) PaperTag(label: reason, emphasis: true),
            for (final category in item.categories) PaperTag(label: category),
          ],
        ),
      ],
      const SizedBox(height: Space.sm),
      Wrap(
        spacing: Space.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (item.paperId != null)
            Text(
              'arXiv ${item.paperId}${item.version == null ? '' : ' · v${item.version}'}',
              style: t.caption.copyWith(color: c.textTertiary),
            ),
          TextButton.icon(
            onPressed: onTap ?? () {},
            icon: const Icon(Icons.open_in_new_rounded, size: Sizes.iconSm),
            label: const Text('Abstract'),
          ),
          TextButton.icon(
            onPressed: onTap ?? () {},
            icon: const Icon(Icons.picture_as_pdf_outlined, size: Sizes.iconSm),
            label: const Text('PDF on arXiv'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _post(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return [
      if (item.text != null) Text(item.text!, maxLines: 10, overflow: TextOverflow.ellipsis, style: t.body),
      if (item.text == null) const _NoPreview(),
      if (item.linkTitle != null) ...[
        const SizedBox(height: Space.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: Sizes.iconSm, color: c.textTertiary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(item.linkTitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.label),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _video(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return [
      _Thumbnail(item: item, overlayIcon: Icons.play_arrow_rounded),
      const SizedBox(height: Space.md),
      if (item.title != null) Text(item.title!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headlineSmall),
      const SizedBox(height: Space.xs),
      Row(
        children: [
          Icon(Icons.open_in_new_rounded, size: Sizes.iconXs, color: c.textTertiary),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(
              'Opens on ${item.source.type.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: c.textTertiary),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _episode(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return [
      if (item.title != null) Text(item.title!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headlineSmall),
      if (item.text != null) ...[
        const SizedBox(height: Space.xs),
        Text(item.text!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall.copyWith(color: c.textSecondary)),
      ],
      const SizedBox(height: Space.md),
      Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: onPlay ?? () {},
            icon: const Icon(Icons.play_arrow_rounded, size: Sizes.iconMd),
            label: const Text('Play'),
          ),
          if (item.duration != null) ...[
            const SizedBox(width: Space.md),
            Text(durationLabel(item.duration!), style: t.caption.copyWith(color: c.textSecondary)),
          ],
        ],
      ),
    ];
  }

  List<Widget> _picture(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return [
      _Thumbnail(item: item, aspectRatio: 4 / 3),
      if (item.title != null || item.text != null) ...[
        const SizedBox(height: Space.sm),
        Text(
          item.title ?? item.text!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    ];
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final source = item.source;
    return Row(
      children: [
        SourceAvatar(source: source, size: Sizes.avatarSm),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: source.name, style: t.label.copyWith(color: c.text)),
                if (source.handle != null) TextSpan(text: '  ${source.handle}'),
                TextSpan(text: '  ·  ${timeAgo(item.publishedAt)}'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(color: c.textTertiary),
          ),
        ),
        const SizedBox(width: Space.sm),
        Tooltip(
          message: '${item.kind.singular} from ${source.type.label}',
          child: Icon(iconForKind(item.kind), size: Sizes.iconSm, color: c.textTertiary),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, this.overlayIcon, this.aspectRatio = 16 / 9});

  final Item item;
  final IconData? overlayIcon;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: item.hasThumbnail
          ? Stack(
              alignment: Alignment.center,
              children: [
                StoryVisual(seed: item.id.hashCode, threads: 5, aspectRatio: aspectRatio),
                if (overlayIcon != null)
                  Container(
                    width: Sizes.playButton,
                    height: Sizes.playButton,
                    decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.85), shape: BoxShape.circle),
                    child: Icon(overlayIcon, color: c.onAccent, size: Sizes.iconXl),
                  ),
                if (item.duration != null)
                  Positioned(
                    right: Space.sm,
                    bottom: Space.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm - Space.xxs, vertical: Space.xxs),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(playerTime(item.duration!), style: t.caption.copyWith(color: c.onAccent)),
                    ),
                  ),
              ],
            )
          : AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                color: c.surfaceSunken,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hide_image_outlined, color: c.textTertiary, size: Sizes.iconLg),
                    const SizedBox(height: Space.xs),
                    Text('No preview', style: t.caption.copyWith(color: c.textTertiary)),
                  ],
                ),
              ),
            ),
    );
  }
}

class _NoPreview extends StatelessWidget {
  const _NoPreview();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text('No preview available', style: context.text.bodySmall.copyWith(color: c.textTertiary));
  }
}

/// A small label on a paper: a category (`cs.CL`) or why it's here. The reason
/// is set apart by weight and an icon, never colour alone.
class PaperTag extends StatelessWidget {
  const PaperTag({super.key, required this.label, this.emphasis = false});

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      // The reason is the point of the tag, so only the card's width cuts it short.
      constraints: emphasis ? null : const BoxConstraints(maxWidth: Sizes.chipMaxWidth),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
      decoration: BoxDecoration(
        color: emphasis ? c.accentSoft : c.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emphasis) ...[
            Icon(Icons.manage_search_rounded, size: Sizes.iconXs, color: c.text),
            const SizedBox(width: Space.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.caption.copyWith(
                color: emphasis ? c.text : c.textSecondary,
                fontWeight: emphasis ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
