import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/keycap.dart';
import '../../shared/widgets/kind_icons.dart';
import '../../shared/widgets/osms_logo.dart';
import '../../shared/widgets/source_chip.dart';
import '../auth/account_row.dart';
import '../briefing/briefing_player.dart';
import 'source_groups.dart';

/// The left pane: where to read, the reader's sources in topic folders, research
/// interests, the briefing, and the account.
class SourcesSidebar extends StatefulWidget {
  const SourcesSidebar({
    super.key,
    required this.topics,
    required this.sources,
    this.allTopics = const [],
    this.suggestions = const [],
    this.interests = const [],
    this.briefing,
    this.user,
    this.selected = 'today',
    this.onSelect,
    this.onAddSource,
    this.onSignIn,
    this.onSearch,
    this.onSettings,
    this.onWhatWeKeep,
    this.onSignOut,
  });

  final VoidCallback? onSettings;
  final VoidCallback? onWhatWeKeep;
  final VoidCallback? onSignOut;

  /// The topics the reader follows (the demo: all of them). Each is a folder of
  /// sources, and selecting one narrows the list to its stories.
  final List<Topic> topics;
  final List<Source> sources;

  /// Every topic and the sources each suggests (onboarding's), to file a source under
  /// its topic. A source no topic suggests goes under "Other sources".
  final List<Topic> allTopics;
  final List<SourceSuggestion> suggestions;

  /// The reader's arXiv research interests.
  final List<ResearchInterest> interests;
  final Briefing? briefing;

  /// Null while signed out: the sidebar then shows the demo's sources and a
  /// sign-in button.
  final User? user;

  /// The selected entry's id: `today`, `saved`, a topic id or a source id.
  final String selected;

  /// The story list follows the selection: Today clears it, a topic or a
  /// source filters to its stories, Saved shows what was kept.
  final ValueChanged<String>? onSelect;
  final VoidCallback? onAddSource;
  final VoidCallback? onSignIn;

  /// Opens the command palette (⌘K). No search field without it.
  final VoidCallback? onSearch;

  @override
  State<SourcesSidebar> createState() => _SourcesSidebarState();
}

class _SourcesSidebarState extends State<SourcesSidebar> {
  /// Up to this many sources, every folder starts open; with more, only the one holding
  /// the selection, so the sidebar stays short (search finds the rest).
  static const _openAllUpTo = 12;

  /// The open folders, once the reader has opened or closed one; until then, the default.
  Set<String>? _chosen;

  List<SourceGroup> get _groups => groupSources(
    sources: widget.sources,
    followed: widget.topics,
    allTopics: widget.allTopics,
    suggestions: widget.suggestions,
  );

  String? _groupOf(List<SourceGroup> groups, String id) =>
      groups.where((g) => g.id == id || g.sources.any((s) => s.id == id)).firstOrNull?.id;

  Set<String> _defaultOpen(List<SourceGroup> groups) => widget.sources.length <= _openAllUpTo
      ? {for (final g in groups) g.id}
      : {?_groupOf(groups, widget.selected)};

  void _toggle(List<SourceGroup> groups, String id) => setState(() {
    final open = _chosen ??= _defaultOpen(groups);
    if (!open.remove(id)) open.add(id);
  });

  @override
  void didUpdateWidget(SourcesSidebar old) {
    super.didUpdateWidget(old);
    // Something picked elsewhere (search) shows inside its open folder.
    if (old.selected != widget.selected) {
      final group = _groupOf(_groups, widget.selected);
      if (group != null) _chosen?.add(group);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final groups = _groups;
    final open = _chosen ?? _defaultOpen(groups);
    final selected = widget.selected;
    final onSelect = widget.onSelect;
    final user = widget.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.lg),
          child: Row(
            children: [
              const OsmsLogo(size: 36),
              const SizedBox(width: Space.sm + Space.xxs),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'OSMS', style: t.headline),
                      TextSpan(text: '\nOne story, many sources', style: t.caption.copyWith(color: c.textTertiary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.onSearch != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
            child: Material(
              color: c.surface,
              shape: StadiumBorder(side: BorderSide(color: c.border)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: widget.onSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: Sizes.iconMd, color: c.textTertiary),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text('Search or jump to', style: t.label.copyWith(color: c.textTertiary))),
                      const Keycap('⌘K'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            children: [
              _NavRow(
                icon: Icons.wb_sunny_outlined,
                label: 'Today',
                selected: selected == 'today',
                onTap: onSelect == null ? null : () => onSelect('today'),
              ),
              _NavRow(
                icon: Icons.bookmark_outline_rounded,
                label: 'Saved',
                selected: selected == 'saved',
                onTap: onSelect == null ? null : () => onSelect('saved'),
              ),
              _NavRow(
                icon: Icons.podcasts_rounded,
                label: 'Podcasts',
                selected: selected == 'podcasts',
                onTap: onSelect == null ? null : () => onSelect('podcasts'),
              ),
              _Heading(user == null ? 'Demo sources' : 'Sources'),
              for (final g in groups) ...[
                _FolderRow(
                  group: g,
                  open: open.contains(g.id),
                  selected: selected == g.id,
                  onToggle: g.sources.isEmpty ? null : () => _toggle(groups, g.id),
                  // A topic's name selects it (its stories) and opens it; "Other sources" only opens.
                  onTap: g.topic == null
                      ? () => _toggle(groups, g.id)
                      : onSelect == null
                      ? null
                      : () {
                          onSelect(g.id);
                          if (g.sources.isNotEmpty && !open.contains(g.id)) _toggle(groups, g.id);
                        },
                ),
                if (open.contains(g.id))
                  for (final s in g.sources)
                    _NavRow(
                      leading: SourceAvatar(source: s, size: Sizes.avatarSm),
                      label: s.name,
                      trailing: Icon(iconForSourceType(s.type), size: Sizes.iconXs, color: c.textTertiary),
                      indent: _FolderRow.indent,
                      selected: selected == s.id,
                      onTap: onSelect == null ? null : () => onSelect(s.id),
                    ),
              ],
              if (widget.sources.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
                  child: Text('No sources yet', style: t.caption.copyWith(color: c.textTertiary)),
                ),
              if (user != null) ...[
                const SizedBox(height: Space.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onAddSource ?? () {},
                    icon: const Icon(Icons.add_rounded, size: Sizes.iconMd),
                    label: const Text('Add a source'),
                  ),
                ),
              ],
              if (widget.interests.isNotEmpty) ...[
                _Heading('Research on arXiv'),
                for (final interest in widget.interests)
                  _NavRow(
                    icon: Icons.science_outlined,
                    label: interest.label,
                    trailing: interest.newThisWeek == 0
                        ? null
                        : Text(
                            '${interest.newThisWeek} new',
                            style: t.caption.copyWith(color: c.newSignal, fontWeight: FontWeight.w600),
                          ),
                    selected: selected == interest.id,
                    onTap: onSelect == null ? null : () => onSelect(interest.id),
                  ),
              ],
            ],
          ),
        ),
        if (widget.briefing != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
            child: BriefingMiniPlayer(briefing: widget.briefing!),
          ),
        const Divider(height: Space.xl),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.xs, Space.md),
          child: AccountRow(
            user: user,
            onSignIn: widget.onSignIn,
            onSettings: widget.onSettings,
            onWhatWeKeep: widget.onWhatWeKeep,
            onSignOut: widget.onSignOut,
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.lg, Space.sm, Space.xs),
      child: Text(
        label,
        style: context.text.caption.copyWith(color: context.colors.textTertiary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A topic's folder of sources (Apple's sidebar guidance: two levels at most, grouped
/// by disclosure). The arrow opens and closes it; the name selects the topic. Closed, it
/// says how many sources it holds: never unread counts. A topic with no sources shows
/// its tag instead of an arrow.
class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.group, required this.open, required this.selected, this.onToggle, this.onTap});

  final SourceGroup group;
  final bool open;
  final bool selected;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  static const _arrow = Sizes.iconMd + Space.sm + Space.xxs;

  /// How far a folder's sources sit in, so their avatars line up under its name.
  static const indent = _arrow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final count = group.sources.length;
    final toggle = onToggle;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.xs),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: _arrow,
                  child: toggle == null
                      ? Icon(Icons.tag_rounded, size: Sizes.iconMd, color: selected ? c.text : c.textSecondary)
                      : Semantics(
                          // Its own control for screen readers, apart from selecting the topic.
                          container: true,
                          button: true,
                          expanded: open,
                          label: '${open ? 'Hide' : 'Show'} ${group.name} sources',
                          excludeSemantics: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(Radii.sm),
                            onTap: toggle,
                            child: AnimatedRotation(
                              turns: open ? 0 : -0.25,
                              duration: Motion.normal,
                              child: Icon(Icons.expand_more_rounded, size: Sizes.iconMd, color: c.textSecondary),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label.copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w600),
                  ),
                ),
                if (!open && count > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.xs),
                    child: Text(
                      '$count',
                      semanticsLabel: count == 1 ? '1 source' : '$count sources',
                      style: t.caption.copyWith(color: c.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selection is a fill plus bold text, never colour alone.
class _NavRow extends StatelessWidget {
  const _NavRow({
    this.icon,
    this.leading,
    required this.label,
    this.trailing,
    this.indent = 0,
    this.selected = false,
    this.onTap,
  });

  final IconData? icon;
  final Widget? leading;
  final String label;
  final Widget? trailing;

  /// Extra space on the leading side: a source inside a folder.
  final double indent;
  final bool selected;

  /// Null renders the row inert (no ripple, no hover): only for rows with
  /// nowhere to go.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Material(
        color: selected ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(Space.sm + indent, Space.sm, Space.sm, Space.sm),
            child: Row(
              children: [
                leading ?? Icon(icon, size: Sizes.iconMd, color: selected ? c.text : c.textSecondary),
                const SizedBox(width: Space.sm + Space.xxs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label.copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
