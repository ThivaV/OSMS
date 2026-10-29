import 'dart:convert';

import 'package:http/browser_client.dart';
import 'package:web/web.dart' as web;

import 'auth_client.dart';
import 'auth_http.dart';

AuthClient createAuthClient(Uri base) => WebAuthClient(base);

/// The web app: the session is an HttpOnly cookie on the sign-in service, sent
/// along with every request (same site, so it works across localhost ports).
class WebAuthClient extends AuthHttp {
  WebAuthClient(Uri base) : super(base, BrowserClient()..withCredentials = true);

  /// Where the sign-in service sends the browser back: this app.
  String get _app => Uri.base.origin;

  @override
  Future<Map<String, String>> sessionHeaders() async => const {};

  @override
  Future<bool> signInWithGoogle() async {
    final response = await postJson('/api/auth/sign-in/social', {
      'provider': 'google',
      'callbackURL': '$_app/',
      // Better Auth adds `error=...` to this; the app reads it when it reloads.
      'errorCallbackURL': '$_app/?sign_in=failed',
    });
    final target = response.statusCode == 200 ? (jsonDecode(response.body) as Map<String, Object?>)['url'] : null;
    if (target is! String) throw const AuthException('Google sign-in isn’t available right now.');
    web.window.location.assign(target);
    return false;
  }

  @override
  Future<void> sendEmailLink(String email) async {
    final response = await postJson('/api/auth/sign-in/magic-link', {'email': email, 'callbackURL': '$_app/'});
    if (response.statusCode != 200) throw const AuthException('That email address didn’t work. Check it and try again.');
  }
}
