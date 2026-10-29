import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'auth_client.dart';
import 'auth_http.dart';

AuthClient createAuthClient(Uri base) => NativeAuthClient(base);

/// The desktop app (macOS). No cookie jar is shared with the browser, so sign-in
/// happens in a system sign-in window that hands back a one-time token; the app
/// trades it for a session token and keeps that in the Keychain.
class NativeAuthClient extends AuthHttp {
  NativeAuthClient(Uri base) : super(base, http.Client());

  static const _sessionKey = 'osms.session';

  /// The legacy Keychain: no Keychain Sharing entitlement or provisioning profile needed.
  static const _storage = FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false));

  @override
  Future<Map<String, String>> sessionHeaders() async {
    final session = await _storage.read(key: _sessionKey);
    return session == null ? const {} : {'Authorization': 'Bearer $session'};
  }

  @override
  Future<AuthProviders> providers() async {
    final providers = await super.providers();
    // Development links finish in a browser, which can't hand the session to the app.
    return AuthProviders(google: providers.google);
  }

  @override
  Future<bool> signInWithGoogle() async {
    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: url('/native/sign-in?provider=google').toString(),
        callbackUrlScheme: 'osms',
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw const AuthException('Sign-in was cancelled.');
      throw const AuthException('The sign-in window couldn’t open. Try again.');
    }
    final callback = Uri.parse(result);
    final token = callback.queryParameters['token'];
    if (token == null) throw const AuthException('Google sign-in didn’t finish. Try again.');

    final response = await postJson('/api/auth/one-time-token/verify', {'token': token});
    final session = response.headers['set-auth-token'];
    if (response.statusCode != 200 || session == null) throw const AuthException('Sign-in expired. Try again.');
    await _storage.write(key: _sessionKey, value: session);
    forgetToken();
    return true;
  }

  @override
  Future<void> sendEmailLink(String email) =>
      throw const AuthException('Email links work in the web app only, in local development.');

  @override
  Future<void> signOut() async {
    try {
      await super.signOut();
    } finally {
      await _storage.delete(key: _sessionKey);
    }
  }

  @override
  Future<void> deleteAccount() async {
    await super.deleteAccount();
    await _storage.delete(key: _sessionKey);
  }
}
