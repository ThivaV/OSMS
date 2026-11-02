// The app's sign-up, sign-in, onboarding, sign-out and deletion flows, against fake
// sign-in and API clients (no network). The real services have their own tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osms/app.dart';
import 'package:osms/core/api/json.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/core/session/account.dart';
import 'package:osms/core/session/session.dart';
import 'package:osms/core/theme/appearance.dart';
import 'package:osms/features/auth/demo_banner.dart';
import 'package:osms/features/briefing/briefing_player.dart';
import 'package:osms/shared/widgets/osms_logo.dart';
import 'package:osms/sample/sample_content.dart' as sample;

import 'support/fakes.dart';

/// Signed in, OSMS shows only the reader's own stories: no invented ones, no sample briefing.
void expectNoSamples() {
  for (final story in sample.stories) {
    expect(find.text(story.title), findsNothing, reason: 'sample story "${story.title}"');
  }
  expect(find.byType(BriefingFloatingBar), findsNothing);
  expect(find.byType(BriefingMiniPlayer), findsNothing);
}

void main() {
  testWidgets('signed out, the start is the sign-in and sign-up page, and nothing else', (tester) async {
    await start(tester);
    expect(find.byType(OsmsLogo), findsOneWidget, reason: 'the mark beside the name');
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Email me a sign-in link'), findsOneWidget);
    for (final gone in [
      'You’re reading the demo',
      'Sixty items become seven stories',
      'Only what changed',
      'Look around the demo first',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    await tapText(tester, 'Create account');
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Sign up with Google'), findsOneWidget);
  });

  testWidgets('older links and ?intent=create open the same page; the demo lives at /demo', (tester) async {
    await start(tester, at: '/sign-in?intent=create');
    expect(find.text('Sign up with Google'), findsOneWidget);
    go(tester, '/demo');
    await tester.pumpAndSettle();
    expect(find.text('You’re reading the demo'), findsWidgets);
    expect(find.textContaining('Its stories are invented samples'), findsWidgets);
    expect(find.text(sample.stories.first.title), findsWidgets);
    await tester.tap(find.descendant(of: find.byType(DemoBanner), matching: find.text('Sign in')));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('first sign-in goes to onboarding, then an empty Today waiting for its sources', (tester) async {
    final (auth, api) = await start(tester);
    await tapText(tester, 'Create account');
    await tapText(tester, 'Sign up with Google');
    expect(auth.signedIn, isTrue);
    expect(find.text('Which language should OSMS write in?'), findsOneWidget);

    await tapText(tester, 'Continue'); // language
    await tapText(tester, 'AI research');
    await tapText(tester, 'Continue'); // topics
    await tapText(tester, 'Continue'); // kinds
    expect(find.text('Follow research on arXiv?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'retrieval-augmented generation');
    await tapText(tester, 'Add');
    await tapText(tester, 'Continue'); // research
    await tapText(tester, 'Start reading');

    expect(api.picks!.topics, {'ai-research'});
    expect(api.picks!.sourceIds, {'1'});
    expect(api.picks!.interest!.keywords, ['retrieval-augmented generation']);
    expect(find.text('Your stories will appear here'), findsWidgets);
    expect(find.text('The first stories from your source appear here once OSMS has collected them.'), findsWidgets);
    expect(find.text('You’re reading the demo'), findsNothing);
    expectNoSamples();
  });

  testWidgets('skipping onboarding saves the picks so far; with no sources, Today offers them again', (tester) async {
    final (_, api) = await start(tester, auth: FakeAuth(signedIn: true));
    expect(find.text('Which language should OSMS write in?'), findsOneWidget);
    await tapText(tester, 'Skip');
    expect(api.onboarded, isTrue);
    expect(api.picks!.topics, isEmpty);
    expect(api.subscriptions, isEmpty);
    expect(find.text('No stories yet. Choose a few topics or sources to begin.'), findsOneWidget);
    expectNoSamples();

    await tapText(tester, 'Choose topics and sources');
    expect(find.text('Which language should OSMS write in?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.text('Which language should OSMS write in?'), findsOneWidget, reason: 'changing picks stays put');
    await tapText(tester, 'Continue'); // language
    await tapText(tester, 'AI research');
    await tapText(tester, 'Continue'); // topics
    await tapText(tester, 'Continue'); // kinds
    await tapText(tester, 'Continue'); // research
    await tapText(tester, 'Start reading');
    expect(api.subscriptions, [FakeApi.arxiv]);
    expect(find.text('The first stories from your source appear here once OSMS has collected them.'), findsWidgets);
    expect(find.text('Choose topics and sources'), findsNothing);
  });

  testWidgets('setting up on one device is enough: this one moves on when another finishes', (tester) async {
    final (_, api) = await start(tester, auth: FakeAuth(signedIn: true));
    expect(find.text('Which language should OSMS write in?'), findsOneWidget);
    api.onboarded = true; // Finished on the web meanwhile.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Which language should OSMS write in?'), findsNothing);
    expect(find.text('You finished setting up on another device.'), findsOneWidget);
  });

  testWidgets('a new reader’s first briefing: Today says it’s being made, then the player appears', (tester) async {
    final (_, api) = await start(tester, auth: FakeAuth(signedIn: true), onboarded: true, briefingMaking: true);
    expect(find.text('Your first briefing is being made'), findsWidgets);
    expect(find.byType(BriefingFloatingBar), findsNothing);

    api
      ..latestBriefing = sample.briefing
      ..briefingInTheMaking = false;
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.byType(BriefingFloatingBar), findsOneWidget, reason: 'no restart needed');
    expect(find.text('Your first briefing is being made'), findsNothing);
  });

  testWidgets('listen: every episode plays, names its show, and links its story', (tester) async {
    final players = <FakePlayback>[];
    await start(tester, players: players);
    go(tester, '/demo');
    await tester.pumpAndSettle();

    await tapText(tester, 'Listen');

    // The hero stands above the episodes: drag until rows lay out.
    final list = find.byKey(const ValueKey('listenList'));
    final episodes = find.textContaining('open weights');
    for (var i = 0; i < 8 && episodes.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
    expect(episodes, findsWidgets, reason: 'the episodes');
    expect(find.text('Gradient Hour'), findsWidgets, reason: 'the show, not just the episode');
    expect(find.textContaining('Discussed in'), findsOneWidget, reason: 'the story link');
    expect(
      find.byTooltip('No audio for this episode yet'),
      findsOneWidget,
      reason: 'no audio is labelled, never a dead button',
    );

    final episodePlay = find.descendant(
      of: find.byKey(const ValueKey('episode-se-1')),
      matching: find.byTooltip('Play'),
    );
    await tester.tap(episodePlay);
    await tester.pumpAndSettle();
    expect(players.expand((p) => p.calls), contains('play'), reason: 'the enclosure streams');
    for (var i = 0; i < 8 && find.text('Now playing').evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, 1500));
      await tester.pumpAndSettle();
    }
    expect(find.text('Now playing'), findsOneWidget);

    final discussedIn = find.textContaining('Discussed in');
    for (var i = 0; i < 8 && discussedIn.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(discussedIn.first);
    await tester.pumpAndSettle();
    await tester.tap(discussedIn.first);
    await tester.pumpAndSettle();
    expect(find.text('Ask this story'), findsOneWidget, reason: 'the episode opens its story');
  });

  testWidgets('listen: show chips filter the playlist and older episodes page in', (tester) async {
    final history = [
      for (var i = 0; i < 55; i++)
        Episode(
          id: 'h-$i',
          title: 'History $i',
          show: i.isEven ? sample.gradientHour : sample.soundwavesDaily,
          publishedAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
        ),
    ];
    await start(tester, auth: FakeAuth(signedIn: true), onboarded: true, readerEpisodes: history);
    await tapText(tester, 'Listen');

    final chips = find.byKey(const ValueKey('showFilter'));
    expect(chips, findsOneWidget, reason: 'two shows to choose between');
    expect(find.text('History 54'), findsOneWidget, reason: 'newest first');
    expect(find.text('History 4'), findsNothing, reason: 'page one holds fifty');

    // The button waits below fifty tall cards: outside the viewport a sliver
    // never lays out, so drag the list until it builds, then expect it.
    final list = find.byKey(const ValueKey('listenList'));
    final older = find.text('Show older episodes');
    for (var i = 0; i < 8 && older.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
    expect(older, findsOneWidget, reason: 'history waits behind the button');

    await tester.tap(older);
    await tester.pumpAndSettle();
    // Back to the top: the subtitle counts what state holds, whatever the
    // viewport has built.
    for (var i = 0; i < 8 && chips.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, 1500));
      await tester.pumpAndSettle();
    }
    expect(find.text('55 episodes from 2 shows'), findsOneWidget, reason: 'the rest pages in, no gaps');
    // And at the very bottom, no button waits: history ends here.
    for (var i = 0; i < 8; i++) {
      await tester.drag(list, const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
    expect(older, findsNothing, reason: 'history ends here');

    final gradient = find.descendant(of: chips, matching: find.text('Gradient Hour'));
    for (var i = 0; i < 8 && gradient.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, 1500));
      await tester.pumpAndSettle();
    }
    await tester.tap(gradient);
    await tester.pumpAndSettle();
    expect(find.text('History 54'), findsOneWidget, reason: 'still the gradient episodes');
    expect(find.text('History 53'), findsNothing, reason: 'the other show filters out');
    expect(find.text('Show older episodes'), findsNothing, reason: 'one show fits on a page');
  });

  testWidgets('listen: type chips narrow the shelves, past briefings replay, videos link their story', (tester) async {
    Briefing briefing(String id, DateTime date, String storyId, String title) => Briefing(
      id: id,
      date: date,
      audioUrl: 'https://briefings.example/$id.wav',
      total: const Duration(minutes: 6),
      chapters: [BriefingChapter(storyId: storyId, title: title, duration: const Duration(minutes: 6))],
    );
    final today = briefing('b-today', DateTime(2026, 11, 1, 7), sample.halcyon.id, sample.halcyon.title);
    final past = briefing('b-past', DateTime(2026, 10, 31, 7), sample.selene.id, sample.selene.title);
    final videos = [
      Video(
        id: 'v1',
        title: 'Selene lands, live',
        source: sample.launchpadLens,
        publishedAt: DateTime(2026, 10, 31, 8),
        duration: const Duration(minutes: 10),
        link: 'https://launchpad.example/v1',
        storyId: sample.selene.id,
        storyTitle: sample.selene.title,
      ),
      Video(
        id: 'v2',
        title: 'A walk around the pad',
        source: sample.launchpadLens,
        publishedAt: DateTime(2026, 10, 30, 18),
        link: 'https://launchpad.example/v0',
      ),
    ];
    final players = <FakePlayback>[];
    await start(
      tester,
      players: players,
      auth: FakeAuth(signedIn: true),
      onboarded: true,
      readerStories: [sample.halcyon, sample.selene],
      readerEpisodes: [sample.sampleEpisodes.first],
      briefing: today,
      readerBriefings: [past],
      readerVideos: videos,
    );
    await tapText(tester, 'Listen');

    expect(find.text('Morning briefing'), findsOneWidget, reason: 'today’s hero');
    expect(
      find.text('2 briefings  ·  1 episode from 1 show  ·  2 videos'),
      findsOneWidget,
      reason: 'the subtitle counts every shelf',
    );
    final types = find.byKey(const ValueKey('typeFilter'));
    expect(types, findsOneWidget, reason: 'three shelves to choose between');

    // Briefings: the hero, then history, each with its documents.
    await tester.tap(find.descendant(of: types, matching: find.text('Briefings')));
    await tester.pumpAndSettle();
    expect(find.text('Earlier briefings'), findsOneWidget);
    expect(find.text(sample.selene.title), findsWidgets, reason: 'the past briefing names its story');

    // Replaying the past briefing holds the slot: its audio plays, and the
    // hero offers the way back to today.
    final list = find.byKey(const ValueKey('listenList'));
    final pastRow = find.byKey(const ValueKey('pastBriefing-b-past'));
    for (var i = 0; i < 8 && pastRow.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.descendant(of: pastRow, matching: find.byTooltip('Play')));
    await tester.pumpAndSettle();
    expect(
      players.where((p) => p.url == 'https://briefings.example/b-past.wav').expand((p) => p.calls),
      contains('play'),
      reason: 'the past recording streams',
    );
    for (var i = 0; i < 8 && find.text('Back to today’s briefing').evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, 1500));
      await tester.pumpAndSettle();
    }
    expect(find.text('Back to today’s briefing'), findsOneWidget, reason: 'the slot names its way back');
    await tester.tap(find.text('Back to today’s briefing'));
    await tester.pumpAndSettle();
    expect(find.text('Back to today’s briefing'), findsNothing, reason: 'today holds the slot again');

    // Videos: rows, not a player — a story link where there is one, honesty
    // where there isn’t.
    await tester.tap(find.descendant(of: types, matching: find.text('Videos')));
    await tester.pumpAndSettle();
    expect(find.text('Selene lands, live'), findsOneWidget);
    expect(find.text('Not part of a story yet'), findsOneWidget, reason: 'the storiless video says so');
    expect(find.text('Morning briefing'), findsNothing, reason: 'only the videos shelf');
    final discussedIn = find.textContaining('Discussed in').first;
    await tester.ensureVisible(discussedIn);
    await tester.pumpAndSettle();
    await tester.tap(discussedIn);
    await tester.pumpAndSettle();
    expect(find.text('Ask this story'), findsOneWidget, reason: 'the video opens its story');
  });

  testWidgets('the sidebar files sources in topic folders that open, close and narrow the list', (tester) async {
    final semantics = tester.ensureSemantics();
    const blog = Source(id: '9', name: 'A blog no topic suggests', type: SourceType.feed, language: 'en');
    await start(
      tester,
      auth: FakeAuth(signedIn: true),
      onboarded: true,
      subscriptions: const [FakeApi.arxiv, FakeApi.nordic, blog],
      readerStories: [sample.cellcycle, sample.kestrel],
    );
    // AI research is followed; Startups and product holds a source; the rest is other.
    for (final shown in ['AI research', 'arXiv cs.CL', 'Startups and product', 'Nordic Startup Wire', 'Other sources']) {
      expect(find.text(shown), findsWidgets, reason: shown);
    }
    expect(find.text(blog.name), findsOneWidget);
    expect(find.text('Topics'), findsNothing, reason: 'topics are the folders now, not a second list');

    await tester.tap(find.bySemanticsLabel('Hide Startups and product sources'));
    await tester.pumpAndSettle();
    expect(find.text('Nordic Startup Wire'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('1 source')), findsOneWidget, reason: 'a closed folder says what it holds');

    expect(find.text(sample.kestrel.title), findsWidgets);
    await tapText(tester, 'Startups and product');
    expect(find.text('Nordic Startup Wire'), findsOneWidget, reason: 'selecting a folder opens it');
    expect(find.text(sample.cellcycle.title), findsWidgets, reason: 'its stories');
    expect(find.text(sample.kestrel.title), findsNothing, reason: 'and only its stories');
    expect(find.text('Startups and product'), findsNWidgets(2), reason: 'titled after the folder');
    semantics.dispose();
  });

  testWidgets('on a phone, picking a folder in the Sources tab shows its stories', (tester) async {
    await start(
      tester,
      auth: FakeAuth(signedIn: true),
      onboarded: true,
      subscriptions: const [FakeApi.arxiv, FakeApi.nordic],
      readerStories: [sample.cellcycle, sample.kestrel],
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await tapText(tester, 'Sources');
    await tester.tap(find.text('Startups and product'));
    await tester.pumpAndSettle();
    expect(find.text(sample.cellcycle.title), findsWidgets, reason: 'back on the stories, narrowed');
    expect(find.text(sample.kestrel.title), findsNothing);
    expect(find.text('Startups and product'), findsWidgets, reason: 'titled after the folder');
  });

  testWidgets('a returning reader lands on Today and never sees sign-in', (tester) async {
    await start(tester, auth: FakeAuth(signedIn: true), onboarded: true);
    expect(find.text('Your stories will appear here'), findsWidgets);
    expectNoSamples();
    for (final elsewhere in ['/sign-in', '/demo']) {
      go(tester, elsewhere);
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsNothing, reason: elsewhere);
      expect(find.text('You’re reading the demo'), findsNothing, reason: elsewhere);
      expect(find.text('Your stories will appear here'), findsWidgets, reason: elsewhere);
    }
  });

  testWidgets('signed out, onboarding and interests send you to sign in', (tester) async {
    await start(tester);
    go(tester, '/onboarding');
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('development sign-in link: asks for an address, then says where the link is', (tester) async {
    final (auth, _) = await start(tester);
    await tapText(tester, 'Email me a sign-in link');
    await tester.enterText(find.byType(TextField), 'ada@users.example');
    await tapText(tester, 'Send link');
    expect(auth.linkSentTo, 'ada@users.example');
    expect(find.text('Open the link in the sign-in log'), findsOneWidget);
  });

  testWidgets('when sign-in is down, the page says so and the demo still works', (tester) async {
    await start(tester, auth: FakeAuth(available: false));
    expect(find.text('Sign-in is unavailable right now'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
    go(tester, '/demo');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign-in is unavailable right now'), findsWidgets);
    expect(find.descendant(of: find.byType(DemoBanner), matching: find.text('Sign in')), findsNothing);
  });

  testWidgets('Delete my account removes OSMS data, then the sign-in account', (tester) async {
    final (auth, api) = await start(tester, auth: FakeAuth(signedIn: true), onboarded: true);
    go(tester, '/settings');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Delete my account'), 300, scrollable: find.byType(Scrollable).first);
    await tapText(tester, 'Delete my account');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
    await tester.pumpAndSettle();
    expect(api.deleted, isTrue);
    expect(auth.deleted, isTrue);
    expect(find.text('Sign in with Google'), findsOneWidget, reason: 'back at the start page');
  });

  test('where a reader may go', () {
    const user = User(id: 'u', displayName: 'U', email: 'u@users.example', language: 'en');
    const out = Session();
    const fresh = Session(account: Account(user: user));
    const back = Session(account: Account(user: user, onboarded: true));
    expect(redirectFor(null, '/settings'), isNull, reason: 'still loading');
    expect(redirectFor(out, '/'), isNull);
    expect(redirectFor(out, '/demo'), isNull);
    expect(redirectFor(out, '/interests'), '/');
    expect(redirectFor(fresh, '/'), '/onboarding');
    expect(redirectFor(fresh, '/what-we-keep'), isNull);
    expect(redirectFor(back, '/demo'), '/');
    expect(redirectFor(back, '/onboarding'), isNull, reason: 'to choose topics and sources again');
    expect(redirectFor(back, '/settings'), isNull);
  });

  test('accounts and settings survive the trip through JSON', () {
    const appearance = Appearance(mode: ThemeMode.dark, paletteId: 'nordlys', pureBlack: true, readingScale: 1.2);
    final back = appearanceFromJson(appearanceToJson(appearance));
    expect([back.mode, back.paletteId, back.pureBlack, back.readingScale], [ThemeMode.dark, 'nordlys', true, 1.2]);

    final account = accountFromJson({
      'id': 'ada',
      'email': 'ada@users.example',
      'display_name': 'Ada Rowan',
      'language': 'da',
      'kinds': ['paper', 'not-a-kind'],
      'topics': [
        {'id': 'ai-research', 'name': 'AI research', 'description': ''},
      ],
      'subscriptions': [
        {'id': '1', 'name': 'arXiv cs.CL', 'type': 'arxiv', 'language': 'en', 'url': null},
      ],
      'interests': [
        {'id': '7', 'keywords': ['RAG'], 'related_terms': [], 'categories': ['cs.CL']},
      ],
      'appearance': null,
      'default_layout': 'card',
      'onboarded': true,
    });
    expect(account.user.language, 'da');
    expect(account.kinds, {ItemKind.paper});
    expect(account.subscriptions.single.type, SourceType.arxiv);
    expect(account.subscriptions.single.followed, isTrue);
    expect(account.interests.single.keywords, ['RAG']);
    expect(account.onboarded, isTrue);
  });
}
