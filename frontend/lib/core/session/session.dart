import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/story_card.dart';
import '../api/api_client.dart';
import '../api/auth_client.dart';
import '../config/env.dart';
import '../models/models.dart';
import '../theme/appearance.dart';
import 'account.dart';

final authClientProvider = Provider<AuthClient>((ref) => createAuthClient(Env.authUrl));

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(Env.apiUrl, ref.watch(authClientProvider)));

/// On the web, a sign-in that failed comes back as `?sign_in=failed` or `?error=...`.
final startupErrorProvider = Provider<String?>((ref) {
  final query = Uri.base.queryParameters;
  return query['sign_in'] == 'failed' || query.containsKey('error') ? 'Sign-in didn’t finish. Try again.' : null;
});

final onboardingOptionsProvider = FutureProvider<OnboardingOptions>(
  (ref) => ref.watch(apiClientProvider).onboardingOptions(),
);

/// Who is reading: a signed-in [account], or nobody (the demo).
class Session {
  const Session({this.account, this.providers = const AuthProviders(), this.available = true, this.message});

  final Account? account;
  final AuthProviders providers;

  /// False when the sign-in service can't be reached. The demo still works.
  final bool available;

  /// The last problem, in plain words, until the next action.
  final String? message;

  bool get signedIn => account != null;

  Session copyWith({Account? account, String? message}) =>
      Session(account: account ?? this.account, providers: providers, available: available, message: message);

  Session signedOut({String? message}) => Session(providers: providers, available: available, message: message);
}

final sessionProvider = AsyncNotifierProvider<SessionController, Session>(SessionController.new);

class SessionController extends AsyncNotifier<Session> {
  Timer? _saveAppearance;

  AuthClient get _auth => ref.read(authClientProvider);
  ApiClient get _api => ref.read(apiClientProvider);
  Session get _now => state.value ?? const Session();

  @override
  Future<Session> build() async {
    ref.onDispose(() => _saveAppearance?.cancel());
    final auth = ref.watch(authClientProvider);
    final AuthProviders providers;
    try {
      providers = await auth.providers();
    } on AuthException catch (e) {
      return Session(available: false, message: e.message);
    }
    try {
      final user = await auth.currentUser();
      if (user == null) return Session(providers: providers, message: ref.read(startupErrorProvider));
      return Session(providers: providers, account: await ref.read(apiClientProvider).me());
    } on AuthException catch (e) {
      return Session(providers: providers, message: e.message);
    } on ApiException catch (e) {
      return Session(providers: providers, message: e.message);
    }
  }

  void _set(Session session) => state = AsyncData(session);

  void _accountChanged(Account account) => _set(_now.copyWith(account: account));

  void clearMessage() => _set(_now.copyWith());

  Future<void> signInWithGoogle() async {
    try {
      if (await _auth.signInWithGoogle()) {
        ref.invalidateSelf();
        await future;
      }
    } on AuthException catch (e) {
      _set(_now.copyWith(message: e.message));
    }
  }

  /// Throws [AuthException] with a message for the reader.
  Future<void> sendEmailLink(String email) => _auth.sendEmailLink(email);

  /// Throws [ApiException] with a message for the reader.
  Future<void> completeOnboarding(OnboardingPicks picks) async =>
      _accountChanged(await _api.completeOnboarding(picks));

  /// Replaces the first research interest (or adds one), keeping the others.
  Future<void> saveInterest(InterestDraft draft) async {
    final others = [
      for (final i in (_now.account?.interests ?? const <ResearchInterest>[]).skip(1))
        InterestDraft(keywords: i.keywords, relatedTerms: i.relatedTerms, categories: i.categories),
    ];
    _accountChanged(await _api.saveInterests([draft, ...others]));
  }

  /// Applies at once; saves to the account shortly after, so a slider doesn't flood the API.
  void updateAppearance(Appearance appearance) {
    final account = _now.account;
    if (account == null) {
      ref.read(localAppearanceProvider.notifier).set(appearance);
      return;
    }
    _accountChanged(account.copyWith(appearance: appearance));
    _saveAppearance?.cancel();
    _saveAppearance = Timer(const Duration(milliseconds: 600), () => _save(appearance: appearance));
  }

  void setLanguage(String language) {
    final account = _now.account;
    if (account == null) return;
    _accountChanged(account.copyWith(language: language));
    _save(language: language);
  }

  void setDefaultLayout(StoryCardLayout layout) {
    final account = _now.account;
    if (account == null) return;
    _accountChanged(account.copyWith(defaultLayout: layout));
    _save(defaultLayout: layout);
  }

  Future<void> _save({Appearance? appearance, String? language, StoryCardLayout? defaultLayout}) async {
    try {
      await _api.saveSettings(appearance: appearance, language: language, defaultLayout: defaultLayout);
    } on ApiException catch (e) {
      _set(_now.copyWith(message: 'Your change wasn’t saved. ${e.message}'));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException {
      // Signed out here either way; the session expires on its own.
    }
    _set(_now.signedOut());
  }

  /// OSMS's data first (the API), then the sign-in account. Throws [ApiException]
  /// if the first step fails, so nothing is half-deleted silently.
  Future<void> deleteAccount() async {
    await _api.deleteMe();
    String? message;
    try {
      await _auth.deleteAccount();
    } on AuthException catch (e) {
      message = e.message;
    }
    _set(_now.signedOut(message: message));
  }
}

/// The signed-out visitor's appearance (kept in memory; the account keeps a reader's).
final localAppearanceProvider = NotifierProvider<LocalAppearance, Appearance>(LocalAppearance.new);

class LocalAppearance extends Notifier<Appearance> {
  @override
  Appearance build() => const Appearance();

  void set(Appearance appearance) => state = appearance;
}

/// What the app is themed with right now.
final appearanceProvider = Provider<Appearance>(
  (ref) => ref.watch(sessionProvider).value?.account?.appearance ?? ref.watch(localAppearanceProvider),
);
