// The app's sign-up, sign-in, onboarding, sign-out and deletion flows, against fake
// sign-in and API clients (no network). The real services have their own tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osms/app.dart';
import 'package:osms/core/api/api_client.dart';
import 'package:osms/core/api/auth_client.dart';
import 'package:osms/core/api/json.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/core/session/account.dart';
import 'package:osms/core/session/session.dart';
import 'package:osms/core/theme/appearance.dart';

class FakeAuth implements AuthClient {
  FakeAuth({this.available = true, this.signedIn = false});

  bool available;
  bool signedIn;
  bool deleted = false;
  String? linkSentTo;

  @override
  Future<AuthProviders> providers() async =>
      available ? const AuthProviders(google: true, emailLink: true) : throw const AuthException('Sign-in is down.');

  @override
  Future<AuthUser?> currentUser() async =>
      signedIn ? const AuthUser(id: 'ada', email: 'ada@users.example', name: 'Ada Rowan') : null;

  @override
  Future<String?> apiToken({bool refresh = false}) async => signedIn ? 'token' : null;

  @override
  Future<bool> signInWithGoogle() async => signedIn = true; // Like the desktop: back signed in.

  @override
  Future<void> sendEmailLink(String email) async => linkSentTo = email;

  @override
  Future<void> signOut() async => signedIn = false;

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    signedIn = false;
  }
}

class FakeApi extends ApiClient {
  FakeApi(this.fakeAuth, {this.onboarded = false}) : super(Uri.parse('http://api.test'), fakeAuth);

  final FakeAuth fakeAuth;
  bool onboarded;
  bool deleted = false;
  OnboardingPicks? picks;
  Appearance? appearance;

  static const topics = [
    Topic(id: 'ai-research', name: 'AI research', description: 'Models, papers, open weights'),
    Topic(id: 'startups', name: 'Startups and product', description: 'Funding, launches'),
  ];
  static const arxiv = Source(id: '1', name: 'arXiv cs.CL', type: SourceType.arxiv, language: 'en');

  Account get _account => Account(
    user: const User(id: 'ada', displayName: 'Ada Rowan', email: 'ada@users.example', language: 'en'),
    topics: onboarded ? [topics.first] : const [],
    subscriptions: onboarded ? const [arxiv] : const [],
    appearance: appearance,
    onboarded: onboarded,
  );

  @override
  Future<OnboardingOptions> onboardingOptions() async => const OnboardingOptions(
    languages: [AppLanguage(code: 'en', nativeName: 'English', englishName: 'English')],
    topics: topics,
    suggestions: [SourceSuggestion(source: arxiv, topicId: 'ai-research', kind: ItemKind.paper)],
  );

  @override
  Future<Account> me() async => _account;

  @override
  Future<Account> completeOnboarding(OnboardingPicks picks) async {
    this.picks = picks;
    onboarded = true;
    return _account;
  }

  @override
  Future<Account> saveSettings({appearance, language, defaultLayout}) async {
    this.appearance = appearance ?? this.appearance;
    return _account;
  }

  @override
  Future<void> deleteMe() async => deleted = true;
}

Future<(FakeAuth, FakeApi)> start(WidgetTester tester, {FakeAuth? auth, bool onboarded = false}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fakeAuth = auth ?? FakeAuth();
  final fakeApi = FakeApi(fakeAuth, onboarded: onboarded);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authClientProvider.overrideWithValue(fakeAuth), apiClientProvider.overrideWithValue(fakeApi)],
      child: const OsmsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (fakeAuth, fakeApi);
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void go(WidgetTester tester, String path) =>
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);

void main() {
  testWidgets('signed out: the demo, labelled, with a way to sign in', (tester) async {
    await start(tester);
    expect(find.text('You’re reading the demo'), findsWidgets);
    await tapText(tester, 'Create an account');
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Email me a sign-in link'), findsOneWidget);
  });

  testWidgets('first sign-in goes to onboarding, then Today with sample stories', (tester) async {
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
    expect(find.text('These are sample stories'), findsWidgets);
    expect(find.text('You’re reading the demo'), findsNothing);
  });

  testWidgets('skipping onboarding still saves the picks so far', (tester) async {
    final (_, api) = await start(tester, auth: FakeAuth(signedIn: true));
    expect(find.text('Which language should OSMS write in?'), findsOneWidget);
    await tapText(tester, 'Skip');
    expect(api.onboarded, isTrue);
    expect(api.picks!.topics, isEmpty);
    expect(find.text('These are sample stories'), findsWidgets);
  });

  testWidgets('a returning reader lands on Today and never sees sign-in', (tester) async {
    await start(tester, auth: FakeAuth(signedIn: true), onboarded: true);
    expect(find.text('These are sample stories'), findsWidgets);
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
    expect(redirectFor(back, '/onboarding'), '/');
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
