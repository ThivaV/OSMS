import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'auth_client.dart';
import 'auth_http.dart';

AuthClient createAuthClient(Uri base) => NativeAuthClient(base);

/// Where the desktop app keeps its session token.
abstract interface class SessionStore {
  Future<String?> read();

  Future<void> write(String session);

  Future<void> delete();
}

/// The Keychain. The legacy keychain needs no Keychain Sharing entitlement or
/// provisioning profile, so a locally built app can use it.
class KeychainStore implements SessionStore {
  const KeychainStore();

  static const _key = 'osms.session';
  static const _storage = FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false));

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String session) => _storage.write(key: _key, value: session);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Opens a page in the reader's default browser.
typedef OpenBrowser = Future<bool> Function(Uri url);

Future<bool> _openInBrowser(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

/// The desktop app (macOS). Sign-in happens in the reader's own browser, where they
/// may already be signed in to Google. The app waits on the loopback interface for
/// the browser to come back (RFC 8252), trades the one-time token it brings for a
/// session token, and keeps that in the Keychain.
class NativeAuthClient extends AuthHttp {
  NativeAuthClient(
    Uri base, {
    http.Client? client,
    SessionStore? store,
    OpenBrowser? openBrowser,
    this.timeout = const Duration(minutes: 5),
  }) : _store = store ?? const KeychainStore(),
       _openBrowser = openBrowser ?? _openInBrowser,
       super(base, client ?? http.Client());

  final SessionStore _store;
  final OpenBrowser _openBrowser;

  /// How long to wait for the reader to finish in the browser.
  final Duration timeout;

  @override
  Future<Map<String, String>> sessionHeaders() async {
    final session = await _store.read();
    return session == null ? const {} : {'Authorization': 'Bearer $session'};
  }

  @override
  Future<AuthProviders> providers() async {
    final providers = await super.providers();
    // Development links are opened by hand from the log, outside any flow the app can wait on.
    return AuthProviders(google: providers.google);
  }

  @override
  Future<bool> signInWithGoogle() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final state = _randomState();
    // Listen before the browser opens, so its answer can never arrive first.
    final callback = _callback(server, state);
    try {
      final returnTo = 'http://127.0.0.1:${server.port}/callback?state=$state';
      final start = url('/native/sign-in').replace(queryParameters: {'provider': 'google', 'return_to': returnTo});
      if (!await _openBrowser(start)) throw const AuthException('Your browser couldn’t be opened. Try again.');
      await completeHandOff(await callback);
    } finally {
      callback.ignore();
      await server.close(force: true);
    }
    await _bringToFront();
    return true;
  }

  /// Waits for the browser's request back with this sign-in's [state]; anything else is
  /// refused. Ends when the server closes, so an abandoned sign-in leaves nothing waiting.
  Future<Uri> _callback(HttpServer server, String state) {
    final result = Completer<Uri>();
    final listening = server.listen(
      (request) async {
        final ours = request.uri.path == '/callback' && request.uri.queryParameters['state'] == state;
        if (!ours || result.isCompleted) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        request.response
          ..headers.contentType = ContentType.html
          ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
          ..write(_page(signedIn: request.uri.queryParameters.containsKey('token')));
        await request.response.close();
        result.complete(request.uri);
      },
      onDone: () {
        if (!result.isCompleted) result.completeError(const AuthException('Sign-in was interrupted. Try again.'));
      },
    );
    return result.future
        .timeout(timeout, onTimeout: () => throw const AuthException('Sign-in took too long. Try again.'))
        .whenComplete(listening.cancel);
  }

  /// Trades the one-time token the browser brought back for a session token.
  Future<void> completeHandOff(Uri callback) async {
    if (callback.queryParameters['error'] case final error?) throw AuthException(_problem(error));
    final token = callback.queryParameters['token'];
    if (token == null) throw const AuthException('Google sign-in didn’t finish. Try again.');
    final response = await postJson('/api/auth/one-time-token/verify', {'token': token});
    final session = response.headers['set-auth-token'];
    if (response.statusCode != 200 || session == null) throw const AuthException('Sign-in expired. Try again.');
    await _store.write(session);
    forgetToken();
  }

  @override
  Future<void> sendEmailLink(String email) =>
      throw const AuthException('Email links work in the web app only, in local development.');

  @override
  Future<void> signOut() async {
    try {
      await super.signOut();
    } finally {
      await _store.delete();
    }
  }

  @override
  Future<void> deleteAccount() async {
    await super.deleteAccount();
    await _store.delete();
  }

  static String _randomState() {
    final random = Random.secure();
    return base64Url.encode([for (var i = 0; i < 24; i++) random.nextInt(256)]).replaceAll('=', '');
  }

  static String _problem(String error) => switch (error) {
    'access_denied' => 'Google sign-in was cancelled.',
    'google_off' => 'Google sign-in isn’t set up on the sign-in service yet.',
    'expired' => 'Sign-in took too long. Try again.',
    _ => 'Google sign-in didn’t finish. Try again.',
  };

  /// Back to the app after the browser: a small native call, best effort.
  static Future<void> _bringToFront() async {
    try {
      await const MethodChannel('osms/window').invokeMethod<void>('bringToFront');
    } catch (_) {
      // Not on macOS, or no window to raise: the reader switches back themselves.
    }
  }

  /// What the browser tab shows once it has handed the sign-in back. Fixed text only.
  static String _page({required bool signedIn}) {
    final (title, body) = signedIn
        ? ('You’re signed in to OSMS', 'You can close this tab and go back to the app.')
        : ('Sign-in didn’t finish', 'Go back to the OSMS app and try again.');
    return '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>OSMS</title>'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<style>body{font:16px/1.5 -apple-system,system-ui,sans-serif;max-width:32rem;margin:20vh auto;'
        'padding:0 1.5rem;color:#1d1b20}h1{font-size:1.4rem;margin:0 0 .5rem}p{color:#5c5866;margin:0}</style>'
        '</head><body><h1>$title</h1><p>$body</p></body></html>';
  }
}
