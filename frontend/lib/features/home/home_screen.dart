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

  /// Sidebar selection: `today`, `saved`, a topic id or a source id.
  String _nav = 'today';

  /// Ask this story: the last question, its answer, and the request state.
  /// Until the backend answers, asking ends in the spec'd unavailable state.
  String? _askQuestion;
  AskResult? _askResult;
  bool _askThinking = false;
  bool _askUnavailable = false;

  SessionController get _session => ref.read(sessionProvider.notifier);

  void _selectStory(String? id) => setState(() {
    _selected = id;
    _askQuestion = null;
    _askResult = null;
    _askThinking = false;
    _askUnavailable = false;
  });

  void _askStory(String question) {
    setState(() {
      _askQuestion = question;
      _askResult = null;
      _askThinking = true;
      _askUnavailable = false;
    });
    // No answer service until the backend lands: thinking, then unavailable.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _askThinking = false;
        _askUnavailable = true;
      });
    });
  }

  /// Story-derived prompts for the idle box. From the story, never the reader.
  static List<String> _askSuggestions(Story story) => [
    if (story.disagreements.isNotEmpty) 'What do sources disagree on?',
    if (story.whatsNew.isNotEmpty) 'What is new here?',
    if (story.timeline.isNotEmpty) 'How did this story develop?',
  ];

  /// The stories Today shows: the demo's samples while signed out; signed in, the
  /// reader's own, of which there are none until OSMS collects them.
  static List<Story> _storiesFor(Session session) => session.signedIn ? const [] : sample.stories;

  /// Sidebar taps: research interests live on their own page, everything else
  /// filters the story list (and clears any open story).
  void _selectNav(String id, Session session) {
    if ((session.account?.interests ?? const []).any((i) => i.id == id)) {
      context.go('/interests');
      return;
    }
    _selectStory(null);
    setState(() => _nav = id);
  }

  /// The list follows the sidebar: Today is everything, a topic or a source
  /// narrows to its stories, Saved waits for the kept-store to land.
  List<Story> _visibleStories(Session session) {
    final stories = _storiesFor(session);
    final nav = _nav;
    if (nav == 'today' || nav == 'saved') return nav == 'today' ? stories : const [];
    final topics = session.account?.topics ?? sample.topics;
    final topic = topics.where((t) => t.id == nav).firstOrNull;
    if (topic != null) return stories.where((s) => s.topic == topic.name).toList();
    return stories.where((s) => s.sources.any((src) => src.id == nav)).toList();
  }

  String _navTitle(Session session) => switch (_nav) {
    'today' => 'Today',
    'saved' => 'Saved',
    _ =>
      (session.account?.topics ?? sample.topics).where((t) => t.id == _nav).firstOrNull?.name ??
          (session.account?.subscriptions ?? sample.followedSources)
              .where((s) => s.id == _nav)
              .firstOrNull
              ?.name ??
          'Today',
  };

  void _openPalette(BuildContext context, Session session) {
    final sources = session.account?.subscriptions ?? sample.followedSources;
    CommandPalette.show(context, [
      for (final s in _storiesFor(session))
        CommandItem(
          icon: Icons.article_outlined,
          label: s.title,
          detail: session.signedIn ? s.topic : 'Sample · ${s.topic}',
          group: 'Stories',
          onRun: () => _selectStory(s.id),
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
        onRun: () => _selectStory(null),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).requireValue;
    final account = session.account;
    final user = account?.user;
    final stories = _visibleStories(session);
    final briefing = account == null ? sample.briefing : null;
    // The demo's matched papers, with their reasons, until real matches exist.
    final research = !session.signedIn && _nav == 'today' ? sample.research : const <Item>[];
    final saved = _nav == 'saved';
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
      selected: _nav,
      onSelect: (id) => _selectNav(id, session),
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
        title: _navTitle(session),
        selectedId: _selected,
        layout: layout,
        bottomInset: briefing == null ? Space.xl : ThreePaneLayout.floatingInset,
        banner: banner(),
        sourceCount: sourceCount,
        onChooseSources: chooseSources,
        emptyTitle: saved ? 'Nothing saved yet' : null,
        emptyBody: saved ? 'Save a story from its toolbar and it waits for you here.' : null,
        emptyIcon: saved ? Icons.bookmark_outline_rounded : null,
        onSelect: (s) => _selectStory(s.id),
        onLayoutChanged: (l) {
          setState(() => _layout = l);
          _session.setDefaultLayout(l);
        },
      ),
      overview: TodayOverview(
        stories: stories,
        research: research,
        briefing: briefing,
        user: user,
        banner: banner(),
        sourceCount: sourceCount,
        onChooseSources: chooseSources,
        emptyTitle: saved ? 'Nothing saved yet' : null,
        emptyBody: saved ? 'Save a story from its toolbar and it waits for you here.' : null,
        onOpen: (s) => _selectStory(s.id),
      ),
      detail: story == null
          ? null
          : StoryDetailView(
              key: ValueKey(story.id),
              story: story,
              askQuestion: _askQuestion,
              askResult: _askResult,
              askThinking: _askThinking,
              askUnavailable: _askUnavailable,
              askSuggestions: _askSuggestions(story),
              onAsk: _askStory,
            ),
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
      onBack: () => _selectStory(null),
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
