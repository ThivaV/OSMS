import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/kind_icons.dart';
import '../../shared/widgets/source_chip.dart';

enum AddSourceStatus { idle, searching, found, notFound, opml }

/// One box for a link or handle, OPML import, and a preview of what was found
/// before subscribing. The caller provides scrolling (a bottom sheet or dialog).
class AddSourceSheet extends StatefulWidget {
  const AddSourceSheet({
    super.key,
    this.status = AddSourceStatus.idle,
    this.query = '',
    this.found,
    this.opmlFileName,
    this.opmlSources = const [],
    this.onClose,
  });

  final AddSourceStatus status;
  final String query;
  final DiscoveredSource? found;
  final String? opmlFileName;
  final List<DiscoveredSource> opmlSources;
  final VoidCallback? onClose;

  @override
  State<AddSourceSheet> createState() => _AddSourceSheetState();
}

class _AddSourceSheetState extends State<AddSourceSheet> {
  late final _controller = TextEditingController(text: widget.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      constraints: const BoxConstraints(maxWidth: Sizes.sheetMaxWidth),
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Add a source', style: t.headline)),
              IconButton(tooltip: 'Close', onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
            ],
          ),
          Text(
            'Paste a link, or a handle like @name@social.example, @name.sky.example or r/name.',
            style: t.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: t.body,
                  decoration: const InputDecoration(
                    hintText: 'https://… or @handle',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              FilledButton(onPressed: () {}, child: const Text('Find')),
            ],
          ),
          const SizedBox(height: Space.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.upload_file_rounded, size: Sizes.iconMd),
              label: const Text('Import an OPML file'),
            ),
          ),
          const SizedBox(height: Space.xl),
          switch (widget.status) {
            AddSourceStatus.idle => const _Idle(),
            AddSourceStatus.searching => _Searching(query: widget.query),
            AddSourceStatus.found => _Found(found: widget.found!),
            AddSourceStatus.notFound => const _NotFound(),
            AddSourceStatus.opml => _OpmlPreview(fileName: widget.opmlFileName ?? 'subscriptions.opml', sources: widget.opmlSources),
          },
        ],
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    const types = [
      SourceType.feed,
      SourceType.newsletter,
      SourceType.podcast,
      SourceType.youtube,
      SourceType.mastodon,
      SourceType.bluesky,
      SourceType.reddit,
      SourceType.pixelfed,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Works with', style: t.caption.copyWith(color: c.textTertiary)),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final type in types)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconForSourceType(type), size: Sizes.iconSm, color: c.textSecondary),
                    const SizedBox(width: Space.xs),
                    Text(type.label, style: t.caption.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Text('and more', style: t.caption.copyWith(color: c.textTertiary)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        SizedBox(
          width: Sizes.iconMd,
          height: Sizes.iconMd,
          child: CircularProgressIndicator(strokeWidth: Sizes.focusRing, color: c.textSecondary),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Text(
            'Looking for a feed at $query…',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.body.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _Found extends StatelessWidget {
  const _Found({required this.found});

  final DiscoveredSource found;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final source = found.source;
    final details = [
      source.type.label,
      languageLabel(source.language),
      if (source.handle != null) source.handle!,
      if (found.frequency != null) found.frequency!,
    ].join('  ·  ');

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SourceAvatar(source: source, size: Sizes.avatarLg),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.subhead),
                    const SizedBox(height: Space.xxs),
                    Text(details, style: t.caption.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text('Latest', style: t.caption.copyWith(color: c.textTertiary)),
          const SizedBox(height: Space.xs),
          if (found.latest.isEmpty)
            Text('Nothing published yet.', style: t.bodySmall.copyWith(color: c.textTertiary))
          else
            for (final item in found.latest.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Row(
                  children: [
                    Icon(iconForKind(item.kind), size: Sizes.iconSm, color: c.textTertiary),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        item.title ?? item.text ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Text(timeAgo(item.publishedAt), style: t.caption.copyWith(color: c.textTertiary)),
                  ],
                ),
              ),
          const SizedBox(height: Space.lg),
          Align(
            alignment: Alignment.centerRight,
            child: found.alreadyFollowed
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_rounded, size: Sizes.iconMd),
                    label: const Text('Following'),
                  )
                : FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded, size: Sizes.iconMd),
                    label: const Text('Subscribe'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.search_off_rounded, color: c.textTertiary, size: Sizes.iconLg),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No feed found', style: t.subhead),
              const SizedBox(height: Space.xs),
              Text(
                "We couldn't find a feed at that link. Check the address, or try the site's home page.",
                style: t.bodySmall.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Everything new is ticked; sources already followed or unreachable are not.
class _OpmlPreview extends StatefulWidget {
  const _OpmlPreview({required this.fileName, required this.sources});

  final String fileName;
  final List<DiscoveredSource> sources;

  @override
  State<_OpmlPreview> createState() => _OpmlPreviewState();
}

class _OpmlPreviewState extends State<_OpmlPreview> {
  late final Set<String> _picked = {
    for (final s in widget.sources)
      if (!s.alreadyFollowed && !s.unreachable) s.source.id,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final sources = widget.sources;
    final folders = <String, List<DiscoveredSource>>{};
    for (final s in sources) {
      folders.putIfAbsent(s.folder ?? 'No folder', () => []).add(s);
    }
    final already = sources.where((s) => s.alreadyFollowed).length;
    final unreachable = sources.where((s) => s.unreachable).length;
    final summary = [
      '${plural(sources.length, 'source')} in ${plural(folders.length, 'folder')}',
      if (already > 0) '$already already followed',
      if (unreachable > 0) "$unreachable couldn't be reached",
    ].join('  ·  ');

    if (sources.isEmpty) {
      return Text(
        'No sources found in ${widget.fileName}. Is it an OPML export from another reader?',
        style: t.bodySmall.copyWith(color: c.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.fileName, style: t.subhead),
        const SizedBox(height: Space.xxs),
        Text(summary, style: t.caption.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.md),
        for (final entry in folders.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
            child: Text(entry.key, style: t.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
          ),
          for (final s in entry.value) _OpmlRow(
            discovered: s,
            picked: _picked.contains(s.source.id),
            onChanged: s.alreadyFollowed || s.unreachable
                ? null
                : (on) => setState(() => on ? _picked.add(s.source.id) : _picked.remove(s.source.id)),
          ),
        ],
        const SizedBox(height: Space.lg),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _picked.isEmpty ? null : () {},
            child: Text('Subscribe to ${plural(_picked.length, 'source')}'),
          ),
        ),
      ],
    );
  }
}

class _OpmlRow extends StatelessWidget {
  const _OpmlRow({required this.discovered, required this.picked, required this.onChanged});

  final DiscoveredSource discovered;
  final bool picked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final source = discovered.source;
    final status = discovered.alreadyFollowed
        ? 'Following'
        : discovered.unreachable
        ? "Couldn't reach"
        : null;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!picked),
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xxs),
        child: Row(
          children: [
            Checkbox(value: picked, onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false)),
            SourceAvatar(source: source, size: Sizes.avatarSm),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: source.name, style: t.bodySmall.copyWith(color: c.text)),
                    TextSpan(text: '  ${source.type.label}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(color: c.textTertiary),
              ),
            ),
            if (status != null) ...[
              const SizedBox(width: Space.sm),
              Text(
                status,
                style: t.caption.copyWith(
                  color: discovered.unreachable ? c.error : c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
