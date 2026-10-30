import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/three_pane_layout.dart';
import '../../core/models/models.dart';
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
/// the demo, whose stories are invented samples, labelled, until OSMS collects real
/// ones. Signed in, only the reader's own stories: a new reader, or one without
/// sources, starts with an empty Today that says what comes next.
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

  /// The stories Today shows: the demo's samples while signed out; signed in, the
  /// reader's own, of which there are none until OSMS collects them.
  static List<Story> _storiesFor(Session session) => session.signedIn ? const [] : sample.stories;

  void _openPalette(BuildContext context, Session session) {
    final sources = session.account?.subscriptions ?? sample.followedSources;
    CommandPalette.show(context, [
      for (final s in _storiesFor(session))
        CommandItem(
          icon: Icons.article_outlined,
          label: s.title,
          detail: session.signedIn ? s.topic : 'Sample · ${s.topic}',
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
    final stories = _storiesFor(session);
    final briefing = account == null ? sample.briefing : null;
    final story = stories.where((s) => s.id == _selected).firstOrNull;
    final layout = _layout ?? account?.defaultLayout ?? StoryCardLayout.row;
    final sourceCount = account?.subscriptions.length ?? 0;
    // Until sources can be added one by one from the app, onboarding is where a reader picks them.
    final chooseSources = account != null && sourceCount == 0 ? () => context.go('/onboarding') : null;

    Widget? banner() => account == null
        ? DemoBanner(
            signInAvailable: session.available && session.providers.any,
            samples: true,
            onCreateAccount: () => context.go('/sign-in?intent=create'),
            onSignIn: () => context.go('/sign-in'),
          )
        : null;

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
        bottomInset: briefing == null ? Space.xl : ThreePaneLayout.floatingInset,
        banner: banner(),
        sourceCount: sourceCount,
        onChooseSources: chooseSources,
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
        banner: banner(),
        sourceCount: sourceCount,
        onChooseSources: chooseSources,
        onOpen: (s) => setState(() => _selected = s.id),
      ),
      detail: story == null ? null : StoryDetailView(key: ValueKey(story.id), story: story),
      floatingPlayer: briefing == null ? null : BriefingFloatingBar(briefing: briefing),
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
