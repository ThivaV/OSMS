import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/three_pane_layout.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../../sample/sample_content.dart' as sample;
import '../../shared/widgets/pill_nav.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/source_chip.dart';
import '../../shared/widgets/story_card.dart';
import '../auth/demo_banner.dart';
import '../briefing/briefing_player.dart';
import '../search/command_palette.dart';
import '../sources/sources_sidebar.dart';
import '../stories/sample_banner.dart';
import '../stories/story_list.dart';
import '../stories/today_overview.dart';
import '../story_detail/story_detail_view.dart';

const _phoneTabs = [
  PillNavDestination(icon: Icons.wb_sunny_outlined, label: 'Today'),
  PillNavDestination(icon: Icons.headphones_rounded, label: 'Briefing'),
  PillNavDestination(icon: Icons.bookmark_outline_rounded, label: 'Saved'),
  PillNavDestination(icon: Icons.layers_outlined, label: 'Sources'),
];

/// Today: the three panes, or the overview when no story is open. Signed out, it is
/// the demo; signed in, the reader's own topics, sources and interests around sample
/// stories, each labelled as such until real stories exist.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selected;
  int _phoneTab = 0;
  StoryCardLayout? _layout;

  SessionController get _session => ref.read(sessionProvider.notifier);

  void _openPalette(BuildContext context, Session session) {
    final sources = session.account?.subscriptions ?? sample.followedSources;
    CommandPalette.show(context, [
      for (final s in sample.stories)
        CommandItem(
          icon: Icons.article_outlined,
          label: s.title,
          detail: 'Sample · ${s.topic}',
          group: 'Stories',
          onRun: () => setState(() => _selected = s.id),
        ),
      for (final s in sources)
        CommandItem(
          icon: Icons.rss_feed_rounded,
          label: s.name,
          detail: s.type.label,
          group: 'Sources',
          leading: SourceAvatar(source: s, size: Sizes.avatarSm),
        ),
      CommandItem(
        icon: Icons.science_outlined,
        label: 'Follow research on arXiv',
        group: 'Actions',
        onRun: () => context.go(session.signedIn ? '/interests' : '/sign-in'),
      ),
      CommandItem(
        icon: Icons.tune_rounded,
        label: 'Settings and themes',
        group: 'Actions',
        shortcut: '⌘,',
        onRun: () => context.go('/settings'),
      ),
      if (session.signedIn)
        CommandItem(icon: Icons.logout_rounded, label: 'Sign out', group: 'Actions', onRun: _session.signOut)
      else
        CommandItem(
          icon: Icons.login_rounded,
          label: 'Sign in or create an account',
          group: 'Actions',
          onRun: () => context.go('/sign-in'),
        ),
      CommandItem(
        icon: Icons.wb_sunny_outlined,
        label: 'Go to Today',
        group: 'Actions',
        onRun: () => setState(() => _selected = null),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).requireValue;
    final account = session.account;
    final user = account?.user;
    final stories = sample.stories;
    final briefing = sample.briefing;
    final story = stories.where((s) => s.id == _selected).firstOrNull;
    final layout = _layout ?? account?.defaultLayout ?? StoryCardLayout.row;

    Widget banner() => account == null
        ? DemoBanner(
            signInAvailable: session.available && session.providers.any,
            onCreateAccount: () => context.go('/sign-in?intent=create'),
            onSignIn: () => context.go('/sign-in'),
          )
        : SampleBanner(sourceCount: account.subscriptions.length);

    SourcesSidebar sidebar({bool withSearch = true}) => SourcesSidebar(
      topics: account?.topics ?? sample.topics,
      sources: account?.subscriptions ?? sample.followedSources,
      interests: account?.interests ?? const [],
      briefing: withSearch ? briefing : null,
      user: user,
      onSignIn: () => context.go('/sign-in'),
      onSearch: withSearch ? () => _openPalette(context, session) : null,
      onSettings: () => context.go('/settings'),
      onWhatWeKeep: () => context.go('/what-we-keep'),
      onSignOut: _session.signOut,
    );

    final shell = ThreePaneLayout(
      sidebar: sidebar(),
      list: StoryList(
        stories: stories,
        selectedId: _selected,
        layout: layout,
        bottomInset: ThreePaneLayout.floatingInset,
        banner: banner(),
        onSelect: (s) => setState(() => _selected = s.id),
        onLayoutChanged: (l) {
          setState(() => _layout = l);
          _session.setDefaultLayout(l);
        },
      ),
      overview: TodayOverview(
        stories: stories,
        briefing: briefing,
        user: user,
        // Sample papers only for a reader who follows research, so the section means something.
        research: (account?.interests.isNotEmpty ?? false) ? sample.research : const [],
        banner: banner(),
        onOpen: (s) => setState(() => _selected = s.id),
      ),
      detail: story == null ? null : StoryDetailView(key: ValueKey(story.id), story: story),
      floatingPlayer: BriefingFloatingBar(briefing: briefing),
      phoneNav: PillNav(destinations: _phoneTabs, selected: _phoneTab, onSelect: (i) => setState(() => _phoneTab = i)),
      phoneBody: switch (_phoneTab) {
        1 => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, ThreePaneLayout.floatingInset),
          child: BriefingPlayer(briefing: briefing),
        ),
        2 => const Padding(
          padding: EdgeInsets.all(Space.lg),
          child: QuietNote(
            icon: Icons.bookmark_outline_rounded,
            title: 'Nothing saved yet',
            body: 'Save a story from its toolbar and it waits for you here.',
          ),
        ),
        3 => sidebar(withSearch: false),
        _ => null,
      },
      onBack: () => setState(() => _selected = null),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _openPalette(context, session),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _openPalette(context, session),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () => context.go('/settings'),
      },
      child: Focus(autofocus: true, child: shell),
    );
  }
}
