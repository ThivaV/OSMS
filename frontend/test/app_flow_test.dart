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
import 'package:osms/features/briefing/briefing_player.dart';
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
  testWidgets('signed out: the demo, labelled, with a way to sign in', (tester) async {
    await start(tester);
    expect(find.text('You’re reading the demo'), findsWidgets);
    expect(find.textContaining('Its stories are invented samples'), findsWidgets);
    expect(find.text(sample.stories.first.title), findsWidgets);
    await tapText(tester, 'Create an account');
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Email me a sign-in link'), findsOneWidget);
  });

  testWidgets('first sign-in goes to onboarding, then an empty Today waiting for its sources', (tester) async {
    final (auth, api) = await start(tester);
    await tapText(tester, 'Create an account');
    await tapText(tester, 'Continue with Google');
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

  testWidgets('a returning reader lands on Today and never sees sign-in', (tester) async {
    await start(tester, auth: FakeAuth(signedIn: true), onboarded: true);
    expect(find.text('Your stories will appear here'), findsWidgets);
    expectNoSamples();
    go(tester, '/sign-in');
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('signed out, onboarding and interests send you to sign in', (tester) async {
    await start(tester);
    go(tester, '/onboarding');
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('development sign-in link: asks for an address, then says where the link is', (tester) async {
    final (auth, _) = await start(tester);
    await tapText(tester, 'Create an account');
    await tapText(tester, 'Email me a sign-in link');
    await tester.enterText(find.byType(TextField), 'ada@users.example');
    await tapText(tester, 'Send link');
    expect(auth.linkSentTo, 'ada@users.example');
    expect(find.text('Open the link in the sign-in log'), findsOneWidget);
  });

  testWidgets('when sign-in is down, the demo still works and says so', (tester) async {
    await start(tester, auth: FakeAuth(available: false));
    expect(find.textContaining('Sign-in is unavailable right now'), findsWidgets);
    expect(find.text('Create an account'), findsNothing);
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
    expect(find.text('You’re reading the demo'), findsWidgets);
  });

  test('where a reader may go', () {
    const user = User(id: 'u', displayName: 'U', email: 'u@users.example', language: 'en');
    const out = Session();
    const fresh = Session(account: Account(user: user));
    const back = Session(account: Account(user: user, onboarded: true));
    expect(redirectFor(null, '/settings'), isNull, reason: 'still loading');
    expect(redirectFor(out, '/'), isNull);
    expect(redirectFor(out, '/interests'), '/sign-in');
    expect(redirectFor(fresh, '/'), '/onboarding');
    expect(redirectFor(fresh, '/what-we-keep'), isNull);
    expect(redirectFor(back, '/sign-in'), '/');
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
