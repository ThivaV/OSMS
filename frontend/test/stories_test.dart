// Real stories from the API: the reader's own, and the demo's. Parsed from the wire
// shape the backend sends, shown with their quotes in the source's language and a
// labelled translation, corrections struck through, and marked read when opened.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osms/core/api/json.dart';
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

  testWidgets('signed out, real demo stories replace the samples, and the banner stops calling them invented', (
    tester,
  ) async {
    await start(
      tester,
      demo: [
        storyFromJson(wire),
        storyFromJson({...wire, 'id': '43', 'title': 'Another story'}),
      ],
    );
    expect(find.text('Lumen Fold arrives in Denmark and the US'), findsWidgets);
    // Each demo source once in the sidebar, however many stories it fed.
    expect(find.text('The Launch Desk'), findsOneWidget);
    expect(find.text('You’re reading the demo'), findsWidgets);
    expect(find.textContaining('invented samples'), findsNothing);
  });
}
