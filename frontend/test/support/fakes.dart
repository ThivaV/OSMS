// Fake sign-in and API clients, and a helper that starts the app with them.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osms/app.dart';
import 'package:osms/core/api/api_client.dart';
import 'package:osms/core/api/auth_client.dart';
import 'package:osms/core/audio/briefing_playback.dart';
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

  /// What the interest agent suggests; records the keywords it was asked about.
  InterestSuggestions suggestions = const InterestSuggestions();
  final List<List<String>> suggestedFor = [];

  @override
  Future<InterestSuggestions> suggestInterest(List<String> keywords) async {
    suggestedFor.add(keywords);
    return suggestions;
  }

  /// The reader's matched papers.
  List<Item> papers = const [];

  @override
  Future<List<Item>> research() async => papers;

  /// The latest briefing, signed in or the demo's; null before the first.
  Briefing? latestBriefing;

  @override
  Future<Briefing?> briefing({bool demo = false}) async => latestBriefing;

  /// What [ask] answers; null fails like an unavailable service. Records each question.
  AskResult? answer;
  final List<(String, String, bool)> asked = [];

  @override
  Future<AskResult> ask(String storyId, String question, {bool demo = false}) async {
    asked.add((storyId, question, demo));
    return answer ?? (throw const ApiException('The answer service is unavailable right now.', status: 503));
  }
}

/// Plays nothing: records what the player asked for.
class FakePlayback implements BriefingPlayback {
  FakePlayback(this.url);

  final String url;
  final calls = <String>[];
  final _state = ValueNotifier(const PlaybackState());

  @override
  ValueListenable<PlaybackState> get state => _state;

  @override
  Future<void> play() async {
    calls.add('play');
    _state.value = _state.value.copyWith(playing: true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _state.value = _state.value.copyWith(playing: false);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek ${position.inMilliseconds}');
    _state.value = _state.value.copyWith(position: position);
  }

  @override
  Future<void> setSpeed(double speed) async => calls.add('speed $speed');

  @override
  void dispose() => calls.add('dispose');
}

Future<(FakeAuth, FakeApi)> start(
  WidgetTester tester, {
  FakeAuth? auth,
  bool onboarded = false,
  List<Source>? subscriptions,
  List<Story> readerStories = const [],
  List<Story> demo = const [],
  Briefing? briefing,
  List<FakePlayback>? players,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fakeAuth = auth ?? FakeAuth();
  final fakeApi = FakeApi(fakeAuth, onboarded: onboarded, subscriptions: subscriptions)
    ..readerStories = readerStories
    ..demo = demo
    ..latestBriefing = briefing;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authClientProvider.overrideWithValue(fakeAuth),
        apiClientProvider.overrideWithValue(fakeApi),
        briefingPlaybackProvider.overrideWithValue((url) {
          final player = FakePlayback(url);
          players?.add(player);
          return player;
        }),
      ],
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

void go(WidgetTester tester, String path) => GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);
