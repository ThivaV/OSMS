// Saving a story, sharing it, and adding a source by link: against the fake API, so
// the saved list is the server's and following is OSMS's, not the screen's.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/features/story_detail/story_detail_view.dart';
import 'package:osms/sample/sample_content.dart' as sample;

import 'support/fakes.dart';

const _found = DiscoveredSource(
  source: Source(id: '', name: 'Lab Notes', type: SourceType.feed, language: 'en', url: 'https://labnotes.example/'),
);

/// Opens [story] from whichever of its titles can be tapped (the player can cover one).
Future<void> _open(WidgetTester tester, Story story) async {
  await tester.tap(find.text(story.title).hitTestable().first);
  await tester.pumpAndSettle();
  expect(find.byType(StoryDetailView), findsOneWidget, reason: '${story.title} opened');
}

Future<void> _showSaved(WidgetTester tester) async {
  await tester.tap(find.text('Saved').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a saved story is kept by OSMS, listed under Saved, and unsaves', (tester) async {
    final story = sample.kestrel;
    final (_, api) = await start(
      tester,
      auth: FakeAuth(signedIn: true),
      onboarded: true,
      readerStories: [sample.cellcycle, story],
    );
    await _open(tester, story);
    await tester.tap(find.byTooltip('Save for later'));
    await tester.pumpAndSettle();
    expect(api.savedIds, [story.id], reason: 'sent to OSMS, so every device sees it');
    expect(find.byTooltip('Saved: tap to unsave'), findsOneWidget);

    await _showSaved(tester);
    expect(find.text(story.title), findsWidgets);
    expect(find.text(sample.cellcycle.title), findsNothing, reason: 'only what was saved');
    expect(find.text('Nothing saved yet'), findsNothing);

    await _open(tester, story);
    await tester.tap(find.byTooltip('Saved: tap to unsave'));
    await tester.pumpAndSettle();
    expect(api.savedIds, isEmpty);
  });

  testWidgets('when OSMS refuses a save, the bookmark goes back and a note says so', (tester) async {
    final (_, api) = await start(
      tester,
      auth: FakeAuth(signedIn: true),
      onboarded: true,
      readerStories: [sample.kestrel],
    );
    api.refuseSaving = true;
    await _open(tester, sample.kestrel);
    await tester.tap(find.byTooltip('Save for later'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Save for later'), findsOneWidget);
    expect(find.text('OSMS had a problem. Try again in a moment.'), findsOneWidget);
  });

  testWidgets('signed out, the demo saves on this page only', (tester) async {
    final (_, api) = await start(tester, demo: [sample.kestrel], at: '/demo');
    await _open(tester, sample.kestrel);
    await tester.tap(find.byTooltip('Save for later'));
    await tester.pumpAndSettle();
    expect(api.savedIds, isEmpty, reason: 'no account to keep it in');
    await _showSaved(tester);
    expect(find.text(sample.kestrel.title), findsWidgets);
  });

  testWidgets('the invented samples have no Save or Share', (tester) async {
    await start(tester, at: '/demo');
    await _open(tester, sample.stories.first);
    expect(find.byTooltip('Save for later'), findsNothing);
    expect(find.byTooltip('Share'), findsNothing);
  });

  testWidgets('Share copies the title, the summary and who reported it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final story = sample.kestrel;
    await start(tester, auth: FakeAuth(signedIn: true), onboarded: true, readerStories: [story]);
    await _open(tester, story);
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(copied, startsWith(story.title));
    expect(copied, contains(story.summary));
    expect(copied, contains('Reported by ${story.sources.first.name}'));
    expect(find.textContaining('Copied the story'), findsOneWidget);
  });

  testWidgets('Add a source finds the feed behind a link, then follows it', (tester) async {
    final (_, api) = await start(tester, auth: FakeAuth(signedIn: true), onboarded: true);
    api.discovered = _found;
    await tapText(tester, 'Add a source');
    await tester.enterText(find.byType(TextField), 'labnotes.example');
    await tester.tap(find.widgetWithText(FilledButton, 'Find'));
    await tester.pumpAndSettle();
    expect(api.discoveredFor, ['labnotes.example']);
    expect(find.text('Lab Notes'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Subscribe'));
    await tester.pumpAndSettle();
    expect(api.subscriptions.map((s) => s.name), contains('Lab Notes'));
    expect(find.text('Following Lab Notes. Its stories arrive with the next fetch.'), findsOneWidget);
    expect(find.text('Lab Notes'), findsWidgets, reason: 'in the sidebar now');
  });

  testWidgets('Add a source says so when a link has no feed', (tester) async {
    await start(tester, auth: FakeAuth(signedIn: true), onboarded: true);
    await tapText(tester, 'Add a source');
    await tester.enterText(find.byType(TextField), 'https://no-feed.example');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No feed found'), findsOneWidget);
  });

  testWidgets('signed out, there is no Add a source, and sample episodes say they are samples', (tester) async {
    await start(tester, demo: [sample.kestrel], at: '/demo');
    expect(find.text('Add a source'), findsNothing);
    await tapText(tester, 'Listen');
    expect(find.textContaining('podcast episodes are invented samples'), findsOneWidget);
  });
}
