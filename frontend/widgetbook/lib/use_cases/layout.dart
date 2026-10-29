import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:osms/core/layout/three_pane_layout.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/core/theme/app_theme.dart';
import 'package:osms/core/theme/appearance.dart';
import 'package:osms/core/theme/tokens.dart';
import 'package:osms/features/auth/demo_banner.dart';
import 'package:osms/features/auth/sign_in_page.dart';
import 'package:osms/features/auth/what_we_keep_page.dart';
import 'package:osms/features/briefing/briefing_player.dart';
import 'package:osms/features/onboarding/onboarding_flow.dart';
import 'package:osms/features/search/command_palette.dart';
import 'package:osms/features/settings/settings_page.dart';
import 'package:osms/features/sources/interests_editor.dart';
import 'package:osms/features/sources/sources_sidebar.dart';
import 'package:osms/features/stories/story_list.dart';
import 'package:osms/features/stories/today_overview.dart';
import 'package:osms/features/story_detail/story_detail_view.dart';
import 'package:osms/shared/widgets/pill_nav.dart';
import 'package:osms/shared/widgets/section_header.dart';
import 'package:osms/shared/widgets/source_chip.dart';
import 'package:osms/shared/widgets/story_card.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;

enum _Screen { shell, signIn, whatWeKeep, onboarding, settings, interests }

const _phoneTabs = [
  PillNavDestination(icon: Icons.wb_sunny_outlined, label: 'Today'),
  PillNavDestination(icon: Icons.headphones_rounded, label: 'Briefing'),
  PillNavDestination(icon: Icons.bookmark_outline_rounded, label: 'Saved'),
  PillNavDestination(icon: Icons.layers_outlined, label: 'Sources'),
];

/// The whole app as a clickable prototype: Today overview, three panes,
/// floating player, phone tab bar, ⌘K palette, simulated sign-in, onboarding,
/// research interests and Settings, whose theme choices re-theme everything live.
class _Shell extends StatefulWidget {
  const _Shell({required this.stories, required this.sources, this.user, this.briefing, this.initialSelection});

  final List<Story> stories;
  final List<Source> sources;
  final User? user;
  final Briefing? briefing;
  final String? initialSelection;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late String? _selected = widget.initialSelection;
  late User? _user = widget.user;
  Appearance _appearance = const Appearance();
  StoryCardLayout _layout = StoryCardLayout.row;
  _Screen _screen = _Screen.shell;
  SignInIntent _intent = SignInIntent.signIn;
  bool _signingIn = false;
  int _phoneTab = 0;

  void _go(_Screen screen) => setState(() => _screen = screen);

  void _openSignIn(SignInIntent intent) => setState(() {
    _intent = intent;
    _screen = _Screen.signIn;
  });

  void _continue(SignInProvider provider) {
    setState(() => _signingIn = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _user = fx.user;
        _screen = _intent == SignInIntent.createAccount ? _Screen.onboarding : _Screen.shell;
      });
    });
  }

  void _openPalette(BuildContext context) => CommandPalette.show(context, [
    for (final s in widget.stories)
      CommandItem(
        icon: Icons.article_outlined,
        label: s.title,
        detail: s.topic,
        group: 'Stories',
        onRun: () => setState(() {
          _screen = _Screen.shell;
          _selected = s.id;
        }),
      ),
    for (final s in widget.sources)
      CommandItem(
        icon: Icons.rss_feed_rounded,
        label: s.name,
        detail: s.type.label,
        group: 'Sources',
        leading: SourceAvatar(source: s, size: Sizes.avatarSm),
      ),
    CommandItem(icon: Icons.headphones_rounded, label: 'Play the morning briefing', group: 'Actions', shortcut: 'Space'),
    const CommandItem(icon: Icons.add_rounded, label: 'Add a source', group: 'Actions', shortcut: 'N'),
    CommandItem(
      icon: Icons.science_outlined,
      label: 'Follow research on arXiv',
      group: 'Actions',
      onRun: () => _go(_Screen.interests),
    ),
    CommandItem(
      icon: Icons.tune_rounded,
      label: 'Settings and themes',
      group: 'Actions',
      shortcut: '⌘,',
      onRun: () => _go(_Screen.settings),
    ),
    CommandItem(
      icon: Icons.wb_sunny_outlined,
      label: 'Go to Today',
      group: 'Actions',
      onRun: () => setState(() => _selected = null),
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).brightness;
    return Theme(
      data: AppTheme.forAppearance(_appearance, _appearance.brightnessFor(platform)),
      child: Builder(
        builder: (context) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _openPalette(context),
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _openPalette(context),
          },
          child: Focus(autofocus: true, child: _buildScreen(context)),
        ),
      ),
    );
  }

  Widget _buildScreen(BuildContext context) => switch (_screen) {
    _Screen.signIn => SignInPage(
      initialIntent: _intent,
      status: _signingIn ? SignInStatus.signingIn : SignInStatus.idle,
      pending: SignInProvider.google,
      onContinue: _continue,
      onTryDemo: () => _go(_Screen.shell),
      onWhatWeKeep: () => _go(_Screen.whatWeKeep),
    ),
    _Screen.whatWeKeep => WhatWeKeepPage(
      contactEmail: fx.privacyContact,
      onBack: () => _go(_user == null ? _Screen.signIn : _Screen.shell),
    ),
    _Screen.onboarding => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Center(
          child: Onboarding(
            languages: fx.languages,
            topics: fx.topics,
            suggestions: fx.suggestions,
            researchSuggestions: fx.researchSuggestions,
            onDone: () => _go(_Screen.shell),
          ),
        ),
      ),
    ),
    _Screen.settings => SettingsPage(
      appearance: _appearance,
      onAppearanceChanged: (a) => setState(() => _appearance = a),
      languages: fx.languages,
      defaultLayout: _layout,
      onDefaultLayoutChanged: (l) => setState(() => _layout = l),
      user: _user,
      previewStory: widget.stories.firstOrNull,
      onBack: () => _go(_Screen.shell),
      onWhatWeKeep: () => _go(_Screen.whatWeKeep),
      onResearchInterests: () => _go(_Screen.interests),
      onSignOut: () => setState(() {
        _user = null;
        _screen = _Screen.shell;
      }),
      onDeleteAccount: () => setState(() {
        _user = null;
        _screen = _Screen.shell;
      }),
    ),
    _Screen.interests => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.sheetMaxWidth),
            child: InterestsEditor(
              initialKeywords: fx.interests.first.keywords,
              suggestedTerms: fx.researchSuggestions,
              initialRelated: fx.interests.first.relatedTerms.toSet(),
              initialCategories: fx.interests.first.categories.toSet(),
              preview: fx.research.take(3).toList(),
              previewCount: 46,
              onSave: () => _go(_Screen.shell),
              onClose: () => _go(_Screen.shell),
            ),
          ),
        ),
      ),
    ),
    _Screen.shell => _buildShell(context),
  };

  Widget _buildShell(BuildContext context) {
    final story = widget.stories.where((s) => s.id == _selected).firstOrNull;
    final briefing = widget.briefing;
    // Research interests are the signed-in reader's own; the demo has none.
    final interests = _user == null ? const <ResearchInterest>[] : fx.interests;
    return ThreePaneLayout(
      sidebar: SourcesSidebar(
        topics: fx.topics,
        sources: widget.sources,
        interests: interests,
        user: _user,
        onSignIn: () => _openSignIn(SignInIntent.signIn),
        onSearch: () => _openPalette(context),
        onSettings: () => _go(_Screen.settings),
        onWhatWeKeep: () => _go(_Screen.whatWeKeep),
        onSignOut: () => setState(() => _user = null),
      ),
      list: StoryList(
        stories: widget.stories,
        selectedId: _selected,
        layout: _layout,
        bottomInset: briefing == null ? Space.xl : ThreePaneLayout.floatingInset,
        banner: _user != null
            ? null
            : DemoBanner(
                onCreateAccount: () => _openSignIn(SignInIntent.createAccount),
                onSignIn: () => _openSignIn(SignInIntent.signIn),
              ),
        onSelect: (s) => setState(() => _selected = s.id),
        onLayoutChanged: (l) => setState(() => _layout = l),
      ),
      overview: TodayOverview(
        stories: widget.stories,
        briefing: briefing,
        user: _user,
        research: interests.isEmpty ? const [] : fx.research,
        onOpen: (s) => setState(() => _selected = s.id),
        onOpenPaper: (_) {},
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
        3 => SourcesSidebar(
          topics: fx.topics,
          sources: widget.sources,
          interests: interests,
          user: _user,
          onSignIn: () => _openSignIn(SignInIntent.signIn),
          onSettings: () => _go(_Screen.settings),
        ),
        _ => null,
      },
      onBack: () => setState(() => _selected = null),
    );
  }
}

@widgetbook.UseCase(name: 'Normal', type: ThreePaneLayout, path: '[Layout]')
Widget shellNormal(BuildContext context) =>
    _Shell(stories: fx.stories, sources: fx.followedSources, user: fx.user, briefing: fx.briefing);

@widgetbook.UseCase(name: 'Reading a story', type: ThreePaneLayout, path: '[Layout]')
Widget shellReading(BuildContext context) => _Shell(
  stories: fx.stories,
  sources: fx.followedSources,
  user: fx.user,
  briefing: fx.briefing,
  initialSelection: fx.halcyon.id,
);

@widgetbook.UseCase(name: 'Signed out: click through sign-in', type: ThreePaneLayout, path: '[Layout]')
Widget shellSignedOut(BuildContext context) =>
    _Shell(stories: fx.stories, sources: fx.followedSources, briefing: fx.briefing);

@widgetbook.UseCase(name: 'Empty', type: ThreePaneLayout, path: '[Layout]')
Widget shellEmpty(BuildContext context) => const _Shell(stories: [], sources: [], user: fx.user);

@widgetbook.UseCase(name: 'Extreme content', type: ThreePaneLayout, path: '[Layout]')
Widget shellExtreme(BuildContext context) => _Shell(
  stories: [fx.extremeStory, ...fx.stories, ...fx.stories],
  sources: fx.manySources(40),
  user: fx.longUser,
  briefing: fx.extremeBriefing,
  initialSelection: fx.extremeStory.id,
);
