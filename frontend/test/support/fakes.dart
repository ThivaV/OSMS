// Fake sign-in and API clients, and a helper that starts the app with them.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osms/app.dart';
import 'package:osms/core/api/api_client.dart';
import 'package:osms/core/api/auth_client.dart';
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
  FakeApi(this.fakeAuth, {this.onboarded = false, List<Source>? subscriptions})
    : subscriptions = subscriptions ?? (onboarded ? const [arxiv] : const []),
      super(Uri.parse('http://api.test'), fakeAuth);

  final FakeAuth fakeAuth;
  bool onboarded;

  /// What the reader follows: the sources picked in onboarding.
  List<Source> subscriptions;
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
    subscriptions: subscriptions,
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
    subscriptions = [if (picks.sourceIds.contains(arxiv.id)) arxiv];
    return _account;
  }

  @override
  Future<Account> saveSettings({appearance, language, defaultLayout}) async {
    this.appearance = appearance ?? this.appearance;
    return _account;
  }

  @override
  Future<void> deleteMe() async => deleted = true;

  /// The reader's stories from the pipeline; none until a test gives some.
  List<Story> readerStories = const [];

  /// The demo's real stories; empty means the app shows its labelled samples.
  List<Story> demo = const [];
  final List<String> read = [];

  @override
  Future<List<Story>> stories() async => readerStories;

  @override
  Future<List<Story>> demoStories() async => demo;

  @override
  Future<void> markRead(String storyId) async => read.add(storyId);
}

Future<(FakeAuth, FakeApi)> start(
  WidgetTester tester, {
  FakeAuth? auth,
  bool onboarded = false,
  List<Source>? subscriptions,
  List<Story> readerStories = const [],
  List<Story> demo = const [],
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fakeAuth = auth ?? FakeAuth();
  final fakeApi = FakeApi(fakeAuth, onboarded: onboarded, subscriptions: subscriptions)
    ..readerStories = readerStories
    ..demo = demo;
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
