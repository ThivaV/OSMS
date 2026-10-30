import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/widgets/story_card.dart';
import '../models/models.dart';
import '../session/account.dart';
import '../theme/appearance.dart';
import 'auth_client.dart';
import 'json.dart';

/// The OSMS API said no, or couldn't be reached.
class ApiException implements Exception {
  const ApiException(this.message, {this.status});

  /// In plain words, for the reader.
  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// The OSMS API. Every call carries a short-lived token from the sign-in service;
/// the API takes the reader's id from that token, never from the request.
class ApiClient {
  ApiClient(this.base, this.auth, {http.Client? client}) : _http = client ?? http.Client();

  final Uri base;
  final AuthClient auth;
  final http.Client _http;

  Future<Json?> _send(String method, String path, {Object? body, bool signedIn = true}) async {
    Future<http.Response> attempt({bool refresh = false}) async {
      final token = signedIn ? await auth.apiToken(refresh: refresh) : null;
      if (signedIn && token == null) throw const ApiException('Sign in first.', status: 401);
      final request = http.Request(method, base.resolve(path))
        ..headers.addAll({'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'});
      if (body != null) request.body = jsonEncode(body);
      return http.Response.fromStream(await _http.send(request));
    }

    http.Response response;
    try {
      response = await attempt();
      // A token can expire between fetching and using it: renew once.
      if (response.statusCode == 401 && signedIn) response = await attempt(refresh: true);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('OSMS is unavailable right now. Try again in a moment.');
    }
    if (response.statusCode >= 400) {
      throw ApiException(switch (response.statusCode) {
        401 => 'Sign in again to continue.',
        422 => 'Something you picked isn’t available any more. Try again.',
        503 => 'Sign-in is unavailable right now. Try again in a moment.',
        _ => 'OSMS had a problem. Try again in a moment.',
      }, status: response.statusCode);
    }
    return response.body.isEmpty ? null : jsonDecode(response.body) as Json;
  }

  Future<OnboardingOptions> onboardingOptions() async =>
      onboardingOptionsFromJson((await _send('GET', '/onboarding/options', signedIn: false))!);

  Future<Account> me() async => accountFromJson((await _send('GET', '/me'))!);

  Future<Account> completeOnboarding(OnboardingPicks picks) async =>
      accountFromJson((await _send('PUT', '/me/onboarding', body: onboardingToJson(picks)))!);

  Future<Account> saveInterests(List<InterestDraft> interests) async => accountFromJson(
    (await _send('PUT', '/me/interests', body: {'interests': interests.map(interestToJson).toList()}))!,
  );

  Future<Account> saveSettings({Appearance? appearance, String? language, StoryCardLayout? defaultLayout}) async =>
      accountFromJson(
        (await _send(
          'PATCH',
          '/me/settings',
          body: {
            if (appearance != null) 'appearance': appearanceToJson(appearance),
            'language': ?language,
            if (defaultLayout != null) 'default_layout': defaultLayout.name,
          },
        ))!,
      );

  /// Deletes everything OSMS keeps about the reader. Sign-in deletes the account after.
  Future<void> deleteMe() => _send('DELETE', '/me');

  /// The reader's stories: the ones their sources picked, with what's new since they read each.
  Future<List<Story>> stories() async => storiesFromJson((await _send('GET', '/stories'))!);

  /// The demo's stories, for signed-out visitors: every seed source, no account needed.
  Future<List<Story>> demoStories() async => storiesFromJson((await _send('GET', '/demo/stories', signedIn: false))!);

  /// The reader opened the story: what's new starts again from now.
  Future<void> markRead(String storyId) => _send('POST', '/stories/$storyId/read');
}
