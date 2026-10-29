import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_client.dart';

/// What both platforms share: the sign-in service's endpoints and how to read them.
/// Platforms differ only in how the session travels (cookie or bearer token).
abstract class AuthHttp implements AuthClient {
  AuthHttp(this.base, this.client);

  final Uri base;
  final http.Client client;
  String? _token;
  DateTime? _tokenExpires;

  /// Headers that carry the session: none on the web (the cookie does), a bearer token on the desktop.
  Future<Map<String, String>> sessionHeaders();

  Uri url(String path) => base.resolve(path);

  Future<Object?> getJson(String path) async {
    final response = await _send(() async => client.get(url(path), headers: await sessionHeaders()));
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<http.Response> postJson(String path, [Map<String, Object?> body = const {}]) => _send(
    () async => client.post(
      url(path),
      headers: {'Content-Type': 'application/json', ...await sessionHeaders()},
      body: jsonEncode(body),
    ),
  );

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const AuthException('Sign-in is unavailable right now. You can still look around the demo.');
    }
    if (response.statusCode >= 500) throw const AuthException('Sign-in had a problem. Try again in a moment.');
    return response;
  }

  void forgetToken() => _token = _tokenExpires = null;

  @override
  Future<AuthProviders> providers() async {
    final body = await getJson('/providers') as Map<String, Object?>;
    return AuthProviders(google: body['google'] == true, emailLink: body['emailLink'] == true);
  }

  @override
  Future<AuthUser?> currentUser() async {
    final body = await getJson('/api/auth/get-session');
    if (body is! Map<String, Object?> || body['user'] is! Map<String, Object?>) return null;
    final user = body['user'] as Map<String, Object?>;
    return AuthUser(id: user['id'] as String, email: user['email'] as String, name: (user['name'] as String?) ?? '');
  }

  @override
  Future<String?> apiToken({bool refresh = false}) async {
    final expires = _tokenExpires;
    if (!refresh && _token != null && expires != null && DateTime.now().isBefore(expires)) return _token;
    final response = await _send(() async => client.get(url('/api/auth/token'), headers: await sessionHeaders()));
    if (response.statusCode != 200) {
      forgetToken();
      return null;
    }
    _token = (jsonDecode(response.body) as Map<String, Object?>)['token'] as String;
    // Renew a minute early; the token says when it expires, but the clock that matters is ours.
    _tokenExpires = DateTime.now().add(const Duration(minutes: 14));
    return _token;
  }

  @override
  Future<void> signOut() async {
    await postJson('/api/auth/sign-out');
    forgetToken();
  }

  @override
  Future<void> deleteAccount() async {
    final response = await postJson('/api/auth/delete-user');
    if (response.statusCode != 200) {
      throw const AuthException('Your OSMS data is deleted, but the sign-in account needs a fresh sign-in to go too.');
    }
    forgetToken();
  }
}
