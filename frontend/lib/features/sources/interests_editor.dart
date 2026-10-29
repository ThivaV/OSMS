import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/formatting.dart';

/// Follow research on arXiv by keywords. The reader types keywords and phrases,
/// accepts related terms the interest agent suggests, optionally narrows to
/// categories, and sees in plain words what OSMS will look for before saving.
class InterestsEditor extends StatefulWidget {
  const InterestsEditor({
    super.key,
    this.initialKeywords = const [],
    this.suggestedTerms = const [],
    this.initialRelated = const {},
    this.initialCategories = const {},
    this.flagged = const {},
    this.preview = const [],
    this.previewCount,
    this.embedded = false,
    this.onSave,
    this.onClose,
  });

  final List<String> initialKeywords;

  /// From the interest agent: related terms the reader can add with one tap.
  final List<String> suggestedTerms;
  final Set<String> initialRelated;
  final Set<String> initialCategories;

  /// Keywords the interest agent found outside rule 3 (politics, war). They
  /// stay visible but are never searched.
  final Set<String> flagged;

  /// The latest papers these interests would have pulled.
  final List<Item> preview;

  /// Papers matched in the last 30 days.
  final int? previewCount;

  /// Inside onboarding: no title, close or save button.
  final bool embedded;
  final VoidCallback? onSave;
  final VoidCallback? onClose;

  @override
  State<InterestsEditor> createState() => _InterestsEditorState();
}

class _InterestsEditorState extends State<InterestsEditor> {
  late final List<String> _keywords = [...widget.initialKeywords];
  late final Set<String> _related = {...widget.initialRelated};
  late final Set<String> _categories = {...widget.initialCategories};
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final term = _input.text.trim();
    if (term.isEmpty) return;
    setState(() {
      if (!_keywords.contains(term)) _keywords.add(term);
      _input.clear();
    });
  }

  String _plan() {
    final terms = [
      for (final k in _keywords)
        if (!widget.flagged.contains(k)) k,
      ..._related,
    ];
    if (terms.isEmpty) return 'Add a keyword to see what OSMS will look for.';
    final quoted = terms.map((t) => '“$t”').join(', ');
    final where = _categories.isEmpty ? '' : ', in ${_categories.join(', ')}';
    return 'New papers whose title or abstract mentions $quoted$where, plus papers related to them '
        'by meaning. Checked once a day, after arXiv publishes.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final flaggedHere = _keywords.where(widget.flagged.contains).toList();

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Row(
            children: [
              Expanded(child: Text('Follow research on arXiv', style: t.headline)),
              IconButton(tooltip: 'Close', onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
            ],
          ),
          Text(
            'Add keywords or phrases from your field. OSMS pulls new papers that mention them, '
            'and papers related to them by meaning.',
            style: t.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.lg),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                style: t.body,
                onSubmitted: (_) => _add(),
                decoration: const InputDecoration(
                  hintText: 'e.g. retrieval-augmented generation',
                  prefixIcon: Icon(Icons.manage_search_rounded),
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            FilledButton(onPressed: _add, child: const Text('Add')),
          ],
        ),
        const SizedBox(height: Space.md),
        if (_keywords.isEmpty)
          Text('No keywords yet.', style: t.caption.copyWith(color: c.textTertiary))
        else
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final k in _keywords)
                _KeywordChip(
                  term: k,
                  flagged: widget.flagged.contains(k),
                  onRemove: () => setState(() => _keywords.remove(k)),
                ),
            ],
          ),
        if (flaggedHere.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.block_rounded, size: Sizes.iconSm, color: c.textSecondary),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  'OSMS doesn’t follow politics or war, so ${flaggedHere.map((k) => '“$k”').join(', ')} '
                  'won’t be searched.',
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        ],
        if (widget.suggestedTerms.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text('Related terms OSMS suggests', style: t.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final s in widget.suggestedTerms)
                _ToggleChip(
                  label: s,
                  selected: _related.contains(s),
                  onTap: () => setState(() => _related.contains(s) ? _related.remove(s) : _related.add(s)),
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.lg),
        Text('Categories (optional)', style: t.label.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final cat in arxivCategories)
              Tooltip(
                message: cat.name,
                child: _ToggleChip(
                  label: cat.code,
                  selected: _categories.contains(cat.code),
                  onTap: () => setState(
                    () => _categories.contains(cat.code) ? _categories.remove(cat.code) : _categories.add(cat.code),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Container(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What OSMS will look for', style: t.subhead),
              const SizedBox(height: Space.xs),
              Text(_plan(), style: t.bodySmall.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
        if (widget.preview.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text(
            '${plural(widget.previewCount ?? widget.preview.length, 'paper')} in the last 30 days, for example:',
            style: t.caption.copyWith(color: c.textTertiary),
          ),
          for (final p in widget.preview.take(3)) _PreviewRow(paper: p),
        ],
        if (!widget.embedded) ...[
          const SizedBox(height: Space.lg),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _keywords.isEmpty ? null : (widget.onSave ?? () {}),
              child: const Text('Follow these interests'),
            ),
          ),
        ],
      ],
    );

    if (widget.embedded) return body;
    return Container(
      constraints: const BoxConstraints(maxWidth: Sizes.sheetMaxWidth),
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.border),
      ),
      child: body,
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.term, required this.flagged, required this.onRemove});

  final String term;
  final bool flagged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(maxWidth: Sizes.chipMaxWidth + Space.xxxl),
      padding: const EdgeInsets.only(left: Space.md, right: Space.xxs),
      decoration: BoxDecoration(
        color: flagged ? c.surface : c.accentSoft,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: flagged ? c.borderStrong : c.accentSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flagged) ...[
            Icon(Icons.block_rounded, size: Sizes.iconXs, color: c.textTertiary),
            const SizedBox(width: Space.xs),
          ],
          Flexible(
            child: Text(
              term,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.label.copyWith(
                color: flagged ? c.textTertiary : c.text,
                decoration: flagged ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove $term',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: Sizes.iconSm),
          ),
        ],
      ),
    );
  }
}

/// A pill that toggles. Selected shows a tick and a heavier border.
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = StadiumBorder(
      side: BorderSide(color: selected ? c.accent : c.border, width: selected ? Sizes.focusRing : Sizes.hairline),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.accentSoft : c.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + Space.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_rounded : Icons.add_rounded,
                  size: Sizes.iconSm,
                  color: selected ? c.text : c.textTertiary,
                ),
                const SizedBox(width: Space.xs),
                Flexible(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.paper});

  final Item paper;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final first = paper.authors.isEmpty ? null : paper.authors.first;
    final meta = [
      if (first != null) paper.authors.length > 1 ? '$first et al.' : first,
      if (paper.categories.isNotEmpty) paper.categories.first,
      timeAgo(paper.publishedAt),
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Space.xxs),
            child: Icon(Icons.description_outlined, size: Sizes.iconSm, color: c.textTertiary),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paper.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.label),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
