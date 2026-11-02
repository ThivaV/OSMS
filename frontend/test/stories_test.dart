// Real stories from the API: the reader's own, and the demo's. Parsed from the wire
// shape the backend sends, shown with their quotes in the source's language and a
// labelled translation, corrections struck through, and marked read when opened.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:osms/core/api/json.dart';
import 'package:osms/core/session/research.dart';
import 'package:osms/features/home/home_screen.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/features/story_detail/story_detail_view.dart';

import 'support/fakes.dart';

/// What `GET /stories` sends for one story (invented content, `.example` links).
final Json wire = {
  'id': '42',
  'title': 'Lumen Fold arrives in Denmark and the US',
  'summary': 'The Lumen Fold costs 7,999 kroner in Denmark and \$999 in the US.',
  'summary_points': [
    {
      'text': 'The Lumen Fold costs 7,999 kroner in Denmark and \$999 in the US.',
      'sources': [
        {
          'id': '1',
          'name': 'Bytebladet',
          'type': 'feed',
          'language': 'da',
          'url': 'https://bytebladet.example/',
          'followed': true,
        },
      ],
    },
  ],
  'topic': 'Startups and product',
  'updated_at': '2026-10-30T10:05:00Z',
  'sources': [
    {
      'id': '1',
      'name': 'Bytebladet',
      'type': 'feed',
      'language': 'da',
      'url': 'https://bytebladet.example/',
      'followed': true,
    },
    {
      'id': '2',
      'name': 'The Launch Desk',
      'type': 'feed',
      'language': 'en',
      'url': 'https://launchdesk.example/',
      'followed': false,
    },
  ],
  'kind_counts': {'article': 2, 'hologram': 1},
  'languages': ['da', 'en'],
  'visual_seed': 42,
  'has_illustration': false,
  'last_read_at': null,
  'whats_new': [
    {
      'id': '1',
      'text': 'The Lumen Fold costs 7,999 kroner in Denmark.',
      'sources': [
        {'id': '1', 'name': 'Bytebladet', 'type': 'feed', 'language': 'da', 'url': null, 'followed': true},
      ],
      'reported_at': '2026-10-30T09:20:00Z',
      'quote': 'Lumen Fold koster 7.999 kr.',
      'quote_language': 'da',
      'translation': 'The Lumen Fold costs 7,999 kroner.',
      'source_count': 1,
      'corrects': null,
    },
  ],
  'disagreements': [
    {
      'id': '7',
      'topic': 'Battery',
      'sides': [
        {'value': '4,500 mAh', 'claim': 'It has a 4,500 mAh battery.', 'sources': []},
        {'value': '4,700 mAh', 'claim': 'It has a 4,700 mAh battery.', 'sources': []},
      ],
    },
  ],
  'timeline': [
    {
      'id': 'item-1',
      'at': '2026-10-30T09:20:00Z',
      'text': 'Lumen Fold kommer til Danmark',
      'kind': 'article',
      'source_count': 1,
      'url': 'https://bytebladet.example/fold',
      'corrected_from': null,
    },
    {
      'id': 'correction-5',
      'at': '2026-10-30T11:00:00Z',
      'text': 'Bytebladet corrected Battery: 4,700 mAh',
      'kind': 'article',
      'source_count': 1,
      'url': null,
      'corrected_from': '4,500 mAh',
    },
  ],
  'why': ['2 sources', '1 new fact', 'Startups and product'],
};

/// A demo briefing with two chapters: stories 42 and 43.
Briefing twoChapters() => briefingFromJson({
  'id': '7',
  'created_at': '2026-10-31T06:00:00Z',
  'language': 'en',
  'duration_ms': 64000,
  'audio_url': 'http://api.example/briefings/7/audio?expires=1&signature=s',
  'chapters': [
    {
      'story_id': '42',
      'title': 'The Lumen Fold arrives',
      'start_ms': 4000,
      'duration_ms': 30000,
      'new_fact_count': 2,
      'sentences': [],
      'checked_by': 'muse-voice-transcribe-1.0',
    },
    {
      'story_id': '43',
      'title': 'Kestrel comes to Aarhus',
      'start_ms': 35000,
      'duration_ms': 29000,
      'new_fact_count': 1,
      'sentences': [],
      'checked_by': 'muse-voice-transcribe-1.0',
    },
  ],
});

void main() {
  test('a story survives the trip from the API, unknown kinds dropped', () {
    final story = storyFromJson(wire);
    expect(story.kindCounts, {ItemKind.article: 2});
    expect(story.sources.where((s) => s.followed).map((s) => s.name), ['Bytebladet']);
    final claim = story.whatsNew.single;
    expect(
      [claim.quote, claim.quoteLanguage, claim.translation],
      ['Lumen Fold koster 7.999 kr.', 'da', 'The Lumen Fold costs 7,999 kroner.'],
    );
    expect(claim.singleSource, isTrue);
    expect(story.timeline.last.correctedFrom, '4,500 mAh');
    expect(story.timeline.first.url, 'https://bytebladet.example/fold');
    expect(story.why, ['2 sources', '1 new fact', 'Startups and product']);
  });

  testWidgets('a reader sees their real stories; opening one marks it read and shows its evidence', (tester) async {
    final (_, api) = await start(
      tester,
      auth: FakeAuth(signedIn: true),
      onboarded: true,
      readerStories: [storyFromJson(wire)],
    );
    expect(find.text('Lumen Fold arrives in Denmark and the US'), findsWidgets);
    expect(find.text('Your stories will appear here'), findsNothing);

    await tester.tap(find.text('Lumen Fold arrives in Denmark and the US').first);
    await tester.pumpAndSettle();
    expect(api.read, ['42']);
    expect(find.text('“Lumen Fold koster 7.999 kr.”'), findsOneWidget);
    expect(find.text('TRANSLATED BY OSMS'), findsOneWidget);
    expect(find.text('One source so far'), findsOneWidget);
    expect(find.textContaining('Here because: 2 sources'), findsOneWidget);
    final page = find.descendant(of: find.byType(StoryDetailView), matching: find.byType(Scrollable)).first;
    final correction = find.textContaining('Corrected', findRichText: true);
    await tester.scrollUntilVisible(correction, 300, scrollable: page);
    expect(correction, findsOneWidget);
  });

  test('a story’s picture comes with its credit and link, https only', () {
    final pictured = storyFromJson({
      ...wire,
      'image': {'url': 'https://cdn.launchdesk.example/fold.jpg', 'source': 'The Launch Desk', 'link': 'https://launchdesk.example/fold'},
    });
    expect([pictured.image!.url, pictured.image!.source, pictured.image!.link], [
      'https://cdn.launchdesk.example/fold.jpg',
      'The Launch Desk',
      'https://launchdesk.example/fold',
    ]);
    expect(pictured.largeImage, isNotNull);
    final thumb = storyFromJson({
      ...wire,
      'image': {'url': 'https://cdn.example/x-184x111.jpg', 'source': 'x', 'small': true},
    });
    expect([thumb.image != null, thumb.largeImage], [true, isNull], reason: 'a thumbnail: list rows only');
    expect(storyFromJson({...wire, 'image': {'url': 'http://cdn.example/x.jpg', 'source': 'x'}}).image, isNull);
    expect(storyFromJson(wire).image, isNull, reason: 'no picture: the illustration or the drawn art');
  });

  testWidgets('a picture that can’t load leaves the drawn art, and the story page still works', (tester) async {
    final story = storyFromJson({
      ...wire,
      'image': {'url': 'https://cdn.launchdesk.example/missing.jpg', 'source': 'The Launch Desk', 'link': null},
    });
    await start(tester, demo: [story], at: '/demo');
    await tapText(tester, story.title);
    expect(tester.takeException(), isNull);
    expect(find.text('Image: The Launch Desk'), findsNothing, reason: 'no credit for a picture that never showed');
  });

  testWidgets('signed out, real demo stories replace the samples, and the banner stops calling them invented', (
    tester,
  ) async {
    await start(
      tester,
      demo: [
        storyFromJson(wire),
        storyFromJson({...wire, 'id': '43', 'title': 'Another story'}),
      ],
      at: '/demo',
    );
    expect(find.text('Lumen Fold arrives in Denmark and the US'), findsWidgets);
    // Each demo source once in the sidebar, however many stories it fed.
    expect(find.text('The Launch Desk'), findsOneWidget);
    expect(find.text('You’re reading the demo'), findsWidgets);
    expect(find.textContaining('invented samples'), findsNothing);
  });

  test('an answer survives the trip from the API, each sentence with its sources', () {
    final answer = askResultFromJson({
      'question': 'What does it cost?',
      'reported': true,
      'sentences': [
        {
          'text': 'Bytebladet reports 7,999 kroner.',
          'claim_ids': ['7'],
          'sources': [(wire['sources']! as List)[0]],
        },
      ],
    });
    expect(answer.reported, isTrue);
    expect(answer.segments.single.sources.single.name, 'Bytebladet');
  });

  Future<void> ask(WidgetTester tester, String question) async {
    await tester.tap(find.text('Lumen Fold arrives in Denmark and the US').first);
    await tester.pumpAndSettle();
    final page = find.descendant(of: find.byType(StoryDetailView), matching: find.byType(Scrollable)).first;
    final field = find.widgetWithText(TextField, 'Ask about this story');
    await tester.scrollUntilVisible(field, 300, scrollable: page);
    await tester.enterText(field, question);
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
  }

  testWidgets('a reader asks a story and gets an answer from its checked facts', (tester) async {
    final (_, api) = await start(
      tester,
      auth: FakeAuth(signedIn: true),
      onboarded: true,
      readerStories: [storyFromJson(wire)],
    );
    api.answer = AskResult(
      question: 'What does it cost?',
      reported: true,
      segments: [SummaryPoint(text: 'Bytebladet reports 7,999 kroner.', sources: storyFromJson(wire).sources)],
    );
    await ask(tester, 'What does it cost?');
    expect(api.asked, [('42', 'What does it cost?', false)]);
    expect(find.textContaining('Bytebladet reports 7,999 kroner.', findRichText: true), findsOneWidget);
  });

  testWidgets('signed out, the demo answers too, and a failure offers to ask again', (tester) async {
    final (_, api) = await start(tester, demo: [storyFromJson(wire)], at: '/demo');
    await ask(tester, 'What does it weigh?');
    expect(api.asked, [('42', 'What does it weigh?', true)]);
    expect(find.text('Ask again'), findsOneWidget);
  });

  testWidgets('signed out, the demo briefing plays its real audio, chapter by chapter', (tester) async {
    final players = <FakePlayback>[];
    final briefing = twoChapters();
    await start(tester, demo: [storyFromJson(wire)], at: '/demo', briefing: briefing, players: players);
    expect(find.text('The Lumen Fold arrives'), findsWidgets); // The floating bar and the sidebar's.
    final player = players.single;
    expect(player.url, briefing.audioUrl);
    await tester.tap(find.byTooltip('Play').first);
    await tester.pump();
    expect(player.calls, ['play']);
    await tester.tap(find.byTooltip('Next story').first);
    await tester.pump();
    expect(player.calls.last, 'seek 35000');
    expect(find.text('Kestrel comes to Aarhus'), findsOneWidget);
  });

  testWidgets('Listen plays the story’s chapter of the briefing; a story outside it can’t', (tester) async {
    final players = <FakePlayback>[];
    await start(
      tester,
      demo: [storyFromJson(wire), storyFromJson({...wire, 'id': '44', 'title': 'A story the briefing skipped'})],
      at: '/demo',
      briefing: twoChapters(),
      players: players,
    );
    await tapText(tester, 'Lumen Fold arrives in Denmark and the US');
    await tester.tap(find.widgetWithText(FilledButton, 'Listen'));
    await tester.pump();
    expect(players.single.calls, ['seek 4000', 'play'], reason: 'from the start of its chapter');

    await tapText(tester, 'A story the briefing skipped');
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Listen')).onPressed, isNull);
    expect(find.byTooltip('Not in the latest briefing'), findsOneWidget);
  });

  testWidgets('a reader sees new papers for their research interests, each saying why', (tester) async {
    final (_, api) = await start(
      tester,
      auth: FakeAuth(signedIn: true),
      onboarded: true,
      readerStories: [storyFromJson(wire)],
    );
    api.papers = [
      paperFromJson({
        'id': '9',
        'title': 'Retrieval-Augmented Generation for Danish questions',
        'abstract': 'We study RAG for Danish.',
        'url': 'https://arxiv.example/abs/2610.01234v2',
        'published_at': '2026-10-30T12:00:00Z',
        'source': {'id': '5', 'name': 'arXiv search', 'type': 'arxiv-query', 'language': 'en', 'followed': false},
        'paper_id': '2610.01234',
        'version': 2,
        'matched_terms': ['RAG'],
      }),
    ];
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    container.invalidate(researchProvider);
    await tester.pumpAndSettle();
    expect(find.text('New research for you'), findsOneWidget);
    expect(find.text('Retrieval-Augmented Generation for Danish questions'), findsOneWidget);
    expect(find.textContaining('RAG'), findsWidgets);
  });

  test('an illustration arrives with its address and where its subject is', () {
    final story = storyFromJson({
      ...wire,
      'has_illustration': true,
      'illustration_url': '/visuals/${'0' * 32}.webp',
      'illustration_focus': [0.5, 0.75],
    }, base: Uri.parse('http://api.example:8000/'));
    expect(story.illustrationUrl, 'http://api.example:8000/visuals/${'0' * 32}.webp');
    expect(story.illustrationFocus, const Alignment(0, 0.5));
    expect(storyFromJson(wire).illustrationUrl, isNull);
  });

  testWidgets('the interest agent suggests related terms and flags what OSMS won’t follow', (tester) async {
    final (_, api) = await start(tester, auth: FakeAuth(signedIn: true), onboarded: true);
    api.suggestions = const InterestSuggestions(relatedTerms: ['dense retrieval'], flagged: ['election polling']);
    GoRouter.of(tester.element(find.byType(HomeScreen))).go('/interests');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'election polling');
    await tester.tap(find.text('Add'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.suggestedFor, [
      ['election polling'],
    ]);
    expect(find.text('dense retrieval'), findsOneWidget);
    expect(find.textContaining('OSMS doesn’t follow politics or war'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(api.suggestedFor, hasLength(1)); // A flagged keyword doesn't ask again.
  });
}
