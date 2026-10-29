import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/keycap.dart';
import '../../shared/widgets/kind_icons.dart';
import '../../shared/widgets/source_chip.dart';
import '../auth/account_row.dart';
import '../briefing/briefing_player.dart';

/// The left pane: where to read, topics, the reader's sources, the briefing,
/// and the account.
class SourcesSidebar extends StatelessWidget {
  const SourcesSidebar({
    super.key,
    required this.topics,
    required this.sources,
    this.interests = const [],
    this.briefing,
    this.user,
    this.selected = 'today',
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

  final List<Topic> topics;
  final List<Source> sources;

  /// The reader's arXiv research interests.
  final List<ResearchInterest> interests;
  final Briefing? briefing;

  /// Null while signed out: the sidebar then shows the demo's sources and a
  /// sign-in button.
  final User? user;

  /// The selected entry's id: `today`, `saved`, a topic id or a source id.
  final String selected;
  final VoidCallback? onAddSource;
  final VoidCallback? onSignIn;

  /// Opens the command palette (⌘K). No search field without it.
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.lg),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'OSMS', style: t.headline),
                TextSpan(text: '\nOne story, many sources', style: t.caption.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
        ),
        if (onSearch != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
            child: Material(
              color: c.surface,
              shape: StadiumBorder(side: BorderSide(color: c.border)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onSearch,
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
              _NavRow(icon: Icons.wb_sunny_outlined, label: 'Today', selected: selected == 'today'),
              _NavRow(icon: Icons.bookmark_outline_rounded, label: 'Saved', selected: selected == 'saved'),
              _Heading('Topics'),
              for (final topic in topics)
                _NavRow(icon: Icons.tag_rounded, label: topic.name, selected: selected == topic.id),
              if (interests.isNotEmpty) ...[
                _Heading('Research on arXiv'),
                for (final interest in interests)
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
                  ),
              ],
              _Heading(user == null ? 'Demo sources' : 'Sources'),
              if (sources.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
                  child: Text('No sources yet', style: t.caption.copyWith(color: c.textTertiary)),
                ),
              for (final s in sources)
                _NavRow(
                  leading: SourceAvatar(source: s, size: Sizes.avatarSm),
                  label: s.name,
                  trailing: Icon(iconForSourceType(s.type), size: Sizes.iconXs, color: c.textTertiary),
                  selected: selected == s.id,
                ),
              if (user != null) ...[
                const SizedBox(height: Space.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onAddSource ?? () {},
                    icon: const Icon(Icons.add_rounded, size: Sizes.iconMd),
                    label: const Text('Add a source'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (briefing != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
            child: BriefingMiniPlayer(briefing: briefing!),
          ),
        const Divider(height: Space.xl),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.xs, Space.md),
          child: AccountRow(
            user: user,
            onSignIn: onSignIn,
            onSettings: onSettings,
            onWhatWeKeep: onWhatWeKeep,
            onSignOut: onSignOut,
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

/// Selection is a fill plus bold text, never colour alone.
class _NavRow extends StatelessWidget {
  const _NavRow({this.icon, this.leading, required this.label, this.trailing, this.selected = false});

  final IconData? icon;
  final Widget? leading;
  final String label;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
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
