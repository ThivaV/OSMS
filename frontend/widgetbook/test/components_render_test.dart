// Renders every component with the Widgetbook fixtures at phone, tablet and
// desktop widths, in light and dark, and fails on any layout error (overflow,
// unbounded size, missing Material, ...).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osms/core/layout/three_pane_layout.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/core/theme/app_theme.dart';
import 'package:osms/features/auth/account_row.dart';
import 'package:osms/features/auth/demo_banner.dart';
import 'package:osms/features/auth/sign_in_page.dart';
import 'package:osms/features/auth/what_we_keep_page.dart';
import 'package:osms/features/briefing/briefing_player.dart';
import 'package:osms/core/theme/appearance.dart';
import 'package:osms/core/theme/palettes.dart';
import 'package:osms/features/onboarding/onboarding_flow.dart';
import 'package:osms/features/search/command_palette.dart';
import 'package:osms/features/stories/today_overview.dart';
import 'package:osms/shared/widgets/source_quote.dart';
import 'package:osms/shared/widgets/pill_nav.dart';
import 'package:osms/features/settings/settings_page.dart';
import 'package:osms/features/settings/theme_picker.dart';
import 'package:osms/features/sources/add_source_sheet.dart';
import 'package:osms/features/sources/interests_editor.dart';
import 'package:osms/features/sources/sources_sidebar.dart';
import 'package:osms/features/stories/story_list.dart';
import 'package:osms/features/story_detail/story_detail_view.dart';
import 'package:osms/shared/widgets/decision_log.dart';
import 'package:osms/shared/widgets/disagreement_panel.dart';
import 'package:osms/shared/widgets/item_card.dart';
import 'package:osms/shared/widgets/source_chip.dart';
import 'package:osms/shared/widgets/story_card.dart';
import 'package:osms/shared/widgets/story_timeline.dart';
import 'package:osms/shared/widgets/whats_new_section.dart';
import 'package:osms_widgetbook/fixtures/fixtures.dart' as fx;

const _sizes = {'phone': Size(390, 844), 'tablet': Size(834, 1112), 'desktop': Size(1440, 900)};
final _themes = {'light': AppTheme.light, 'dark': AppTheme.dark};

/// Components that sit inside a scrolling page.
final Map<String, Widget Function()> _sections = {
  for (final layout in StoryCardLayout.values)
    for (final story in [fx.halcyon, fx.selene, fx.microbes, fx.extremeStory])
      'StoryCard ${layout.name} ${story.id}': () => StoryCard(story: story, layout: layout, selected: true),
  'WhatsNew normal': () => WhatsNewSection(claims: fx.halcyon.whatsNew, since: fx.halcyon.lastReadAt),
  'WhatsNew empty': () => WhatsNewSection(claims: const [], since: fx.microbes.lastReadAt),
  'WhatsNew extreme': () => WhatsNewSection(claims: fx.extremeStory.whatsNew, since: fx.extremeStory.lastReadAt),
  'Disagreements normal': () => DisagreementPanel(disagreements: fx.halcyon.disagreements),
  'Disagreements empty': () => const DisagreementPanel(disagreements: []),
  'Disagreements extreme': () => DisagreementPanel(disagreements: fx.extremeStory.disagreements),
  'Timeline normal': () => StoryTimeline(events: fx.halcyon.timeline, lastReadAt: fx.halcyon.lastReadAt),
  'Timeline empty': () => const StoryTimeline(events: []),
  'Timeline extreme': () => StoryTimeline(events: fx.extremeStory.timeline, lastReadAt: fx.extremeStory.lastReadAt),
  'Briefing normal': () => BriefingPlayer(briefing: fx.briefing, initialChapter: 1),
  'Briefing empty': () => const BriefingPlayer(briefing: null),
  'Briefing extreme': () => BriefingPlayer(briefing: fx.extremeBriefing, initialChapter: 12),
  'Mini player': () => BriefingMiniPlayer(briefing: fx.briefing),
  'Mini player empty': () => BriefingMiniPlayer(briefing: Briefing(date: DateTime.now(), chapters: const [])),
  'Source chips': () => Wrap(children: [for (final s in fx.manySources(40)) SourceChip(source: s)]),
  'Source stack': () => SourceStack(sources: fx.manySources(40)),
  for (final (i, item) in [...fx.items, ...fx.emptyItems, ...fx.extremeItems].indexed)
    'ItemCard $i ${item.kind.name}': () => ItemCard(item: item),
  for (final status in AddSourceStatus.values)
    'AddSource ${status.name}': () => AddSourceSheet(
      status: status,
      query: 'https://labnotes.example',
      found: fx.foundSource,
      opmlSources: fx.opmlSources(18),
    ),
  'AddSource extreme': () => AddSourceSheet(status: AddSourceStatus.opml, opmlSources: fx.opmlSources(120)),
  'AddSource with research': () => AddSourceSheet(onFollowResearch: () {}),
  'Interests normal': () => InterestsEditor(
    initialKeywords: fx.interests.first.keywords,
    suggestedTerms: fx.researchSuggestions,
    initialRelated: fx.interests.first.relatedTerms.toSet(),
    initialCategories: fx.interests.first.categories.toSet(),
    preview: fx.research.take(3).toList(),
    previewCount: 46,
    onSave: (_) {},
    onClose: () {},
  ),
  'Interests empty': () => const InterestsEditor(),
  'Interests extreme': () => InterestsEditor(
    initialKeywords: fx.extremeKeywords,
    suggestedTerms: [...fx.researchSuggestions, ...fx.extremeKeywords.take(8)],
    initialCategories: {for (final c in arxivCategories) c.code},
    flagged: fx.flaggedKeywords,
    preview: [fx.extremePaper, ...fx.research],
    previewCount: 2000,
    onSave: (_) {},
    onClose: () {},
  ),
  'Interests embedded': () => InterestsEditor(embedded: true, suggestedTerms: fx.researchSuggestions),
  for (final step in OnboardingStep.values) ...{
    'Onboarding ${step.name}': () => Onboarding(
      languages: fx.languages,
      topics: fx.topics,
      suggestions: fx.suggestions,
      researchSuggestions: fx.researchSuggestions,
      initialStep: step,
      initialTopics: const {'ai-research', 'space'},
    ),
    'Onboarding extreme ${step.name}': () => Onboarding(
      languages: fx.languages,
      topics: [...fx.topics, ...fx.manyTopics],
      suggestions: fx.manySuggestions,
      researchSuggestions: [...fx.researchSuggestions, ...fx.extremeKeywords],
      initialStep: step,
      initialTopics: {'ai-research', for (final t in fx.manyTopics.take(12)) t.id},
    ),
  },
  for (final b in Brightness.values)
    'Theme picker ${b.name}': () =>
        ThemePicker(palettes: Palettes.all, selectedId: 'folio', brightness: b, onSelect: (_) {}),
  for (final query in ['', 'kite', 'nothing matches this'])
    'Command palette "$query"': () => CommandPalette(
      initialQuery: query,
      items: [
        for (final s in fx.stories)
          CommandItem(icon: Icons.article_outlined, label: s.title, detail: s.topic, group: 'Stories'),
        for (final s in fx.manySources(30))
          CommandItem(icon: Icons.rss_feed_rounded, label: s.name, group: 'Sources', leading: SourceAvatar(source: s)),
        const CommandItem(icon: Icons.science_outlined, label: 'Follow research on arXiv', group: 'Actions'),
        const CommandItem(icon: Icons.tune_rounded, label: 'Settings and themes', group: 'Actions', shortcut: '⌘,'),
      ],
    ),
  'Floating player': () => BriefingFloatingBar(briefing: fx.extremeBriefing, chapter: 5),
  'Pill nav': () => PillNav(
    selected: 1,
    onSelect: (_) {},
    destinations: const [
      PillNavDestination(icon: Icons.wb_sunny_outlined, label: 'Today'),
      PillNavDestination(icon: Icons.headphones_rounded, label: 'Briefing'),
      PillNavDestination(icon: Icons.bookmark_outline_rounded, label: 'Saved for later'),
      PillNavDestination(icon: Icons.layers_outlined, label: 'Sources'),
    ],
  ),
  'Account signed in': () => const AccountRow(user: fx.user),
  'Account signed out': () => const AccountRow(),
  'Account long name': () => const AccountRow(user: fx.longUser),
  'Demo banner': () => const DemoBanner(),
  'Source quote translated': () => const SourceQuote(quote: 'Prisen er 7.999 kr.', language: 'da', translation: 'The price is 7,999 kroner.'),
  'Source quote in English': () => const SourceQuote(quote: 'It costs \$999.', language: 'en'),
  'Source quote extreme': () => SourceQuote(quote: 'விலை ' * 60, language: 'ta', translation: 'The price ' * 60),
  'Decisions': () => DecisionLogSection(decisions: fx.halcyonDecisions),
  'Decisions none yet': () => const DecisionLogSection(decisions: []),
  'Decisions before loading': () => DecisionLogSection(load: () async => fx.halcyonDecisions),
  'Decisions extreme': () => DecisionLogSection(
    decisions: [
      for (var i = 0; i < 12; i++)
        Decision(
          id: 'x$i',
          agent: ['triage', 'judge', 'claims', 'verifier', 'writer', 'an-agent-with-a-long-name'][i % 6],
          model: 'muse-spark-open-1026',
          fallback: i.isEven ? 'muse-spark-1.3' : null,
          at: DateTime(2026, 10, 31, 6, i),
          latency: Duration(milliseconds: 900 * i),
          inputTokens: 100000 * i,
          outputTokens: 9999,
          about: 'A headline long enough to need two lines and then some more ' * 4,
          source: 'A source with a very long name indeed',
          reason: 'Because the two items report the same launch on the same day with the same names. ' * 6,
          outcome: 'Wrote “${'a long title ' * 12}”',
        ),
    ],
  ),
  'Demo banner with samples': () => const DemoBanner(samples: true),
  'Demo banner, sign-in down': () => const DemoBanner(signInAvailable: false),
  'Demo banner with samples, sign-in down': () => const DemoBanner(signInAvailable: false, samples: true),
  'Onboarding empty': () => const Onboarding(
    languages: fx.languages,
    topics: fx.topics,
    suggestions: [],
    initialStep: OnboardingStep.sources,
    initialTopics: {'science'},
  ),
};

Widget _shell(
  List<Story> stories,
  List<Source> sources,
  String? selected,
  Briefing? briefing, {
  User? user,
  List<ResearchInterest> interests = const [],
}) => ThreePaneLayout(
  sidebar: SourcesSidebar(topics: fx.topics, sources: sources, interests: interests, briefing: briefing, user: user),
  list: StoryList(
    stories: stories,
    selectedId: selected,
    onLayoutChanged: (_) {},
    banner: user == null ? const DemoBanner() : null,
  ),
  detail: selected == null ? null : StoryDetailView(story: stories.firstWhere((s) => s.id == selected)),
  onBack: () {},
);

/// Components that fill the screen and scroll themselves.
final Map<String, Widget Function()> _screens = {
  'Story page normal': () => Material(child: StoryDetailView(story: fx.halcyon)),
  'Story page empty': () => Material(child: StoryDetailView(story: fx.selene)),
  'Story page extreme': () => Material(child: StoryDetailView(story: fx.extremeStory)),
  'Story list cards': () => Material(child: StoryList(stories: fx.stories, layout: StoryCardLayout.card)),
  'Shell normal': () =>
      _shell(fx.stories, fx.followedSources, fx.halcyon.id, fx.briefing, user: fx.user, interests: fx.interests),
  'Shell signed out': () => _shell(fx.stories, fx.followedSources, null, fx.briefing),
  'Shell empty': () => _shell(const [], const [], null, null, user: fx.user),
  'Shell extreme': () => _shell(
    [fx.extremeStory, ...fx.stories],
    fx.manySources(40),
    fx.extremeStory.id,
    fx.extremeBriefing,
    user: fx.longUser,
    interests: [
      ...fx.interests,
      ResearchInterest(id: 'interest-long', keywords: fx.extremeKeywords, newThisWeek: 1999),
    ],
  ),
  for (final status in SignInStatus.values)
    for (final providers in [const [SignInProvider.google], fx.allSignInProviders])
      for (final intent in SignInIntent.values)
        'Sign in ${status.name} ${providers.length} ${intent.name}': () => SignInPage(
          status: status,
          providers: providers,
          pending: SignInProvider.google,
          error: fx.signedUpElsewhere,
          initialIntent: intent,
          onContinue: (_) {},
          onTryDemo: () {},
        ),
  'What OSMS keeps': () => WhatWeKeepPage(contactEmail: fx.longUser.email, onBack: () {}),
  'Today overview': () => Material(child: TodayOverview(stories: fx.stories, briefing: fx.briefing, user: fx.user)),
  'Today overview with research': () => Material(
    child: TodayOverview(stories: fx.stories, briefing: fx.briefing, user: fx.user, research: fx.research),
  ),
  'Today overview with a banner': () => Material(
    child: TodayOverview(stories: fx.stories, briefing: fx.briefing, banner: const DemoBanner(samples: true)),
  ),
  'Today overview empty with a banner': () => const Material(child: TodayOverview(stories: [], banner: DemoBanner())),
  'Today overview empty': () => const Material(child: TodayOverview(stories: [])),
  'Today overview empty, no sources': () =>
      Material(child: TodayOverview(stories: const [], user: fx.user, onChooseSources: () {}, onAddSource: () {})),
  'Today overview empty, sources followed': () =>
      Material(child: TodayOverview(stories: const [], user: fx.user, sourceCount: 1)),
  'Story list empty, no sources': () =>
      Material(child: StoryList(stories: const [], onChooseSources: () {}, onAddSource: () {})),
  'Story list empty, sources followed': () => const Material(child: StoryList(stories: [], sourceCount: 40)),
  'Today overview extreme': () => Material(
    child: TodayOverview(
      stories: [fx.extremeStory, ...fx.stories],
      briefing: fx.extremeBriefing,
      user: fx.longUser,
      research: [fx.extremePaper, ...fx.research, ...fx.research],
    ),
  ),
  for (final selected in [null, fx.halcyon.id])
    'Shell home with floating bars, selected $selected': () => ThreePaneLayout(
      sidebar: SourcesSidebar(
        topics: fx.topics,
        sources: fx.followedSources,
        interests: fx.interests,
        user: fx.user,
        onSearch: () {},
      ),
      list: StoryList(stories: fx.stories, selectedId: selected, bottomInset: ThreePaneLayout.floatingInset),
      overview: TodayOverview(stories: fx.stories, briefing: fx.briefing, user: fx.user, research: fx.research),
      detail: selected == null ? null : StoryDetailView(story: fx.halcyon),
      floatingPlayer: BriefingFloatingBar(briefing: fx.briefing),
      phoneNav: PillNav(
        selected: 0,
        onSelect: (_) {},
        destinations: const [
          PillNavDestination(icon: Icons.wb_sunny_outlined, label: 'Today'),
          PillNavDestination(icon: Icons.headphones_rounded, label: 'Briefing'),
          PillNavDestination(icon: Icons.bookmark_outline_rounded, label: 'Saved'),
          PillNavDestination(icon: Icons.layers_outlined, label: 'Sources'),
        ],
      ),
      onBack: () {},
    ),
  for (final (name, user, appearance) in [
    ('signed in', fx.user, const Appearance()),
    ('signed out', null, const Appearance()),
    ('extreme', fx.longUser, const Appearance(readingScale: Appearance.maxReadingScale, readingFont: ReadingFont.sans)),
  ])
    'Settings $name': () => SettingsPage(
      appearance: appearance,
      onAppearanceChanged: (_) {},
      languages: fx.languages,
      user: user,
      previewStory: fx.halcyon,
      onBack: () {},
      onResearchInterests: () {},
    ),
};

void main() {
  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    for (final MapEntry(key: themeName, value: theme) in _themes.entries) {
      Future<void> pump(WidgetTester tester, Widget child) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(theme: theme, home: child));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      group('$sizeName · $themeName', () {
        for (final MapEntry(key: name, value: build) in _sections.entries) {
          testWidgets(name, (tester) async {
            await pump(
              tester,
              Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: build()),
                  ),
                ),
              ),
            );
          });
        }
        for (final MapEntry(key: name, value: build) in _screens.entries) {
          testWidgets(name, (tester) async => pump(tester, build()));
        }
      });
    }
  }
}
