// The desktop app's sign-in: the reader's browser, a loopback listener for the result,
// a one-time token traded for a session in the Keychain. The browser and the sign-in
// service are faked; the loopback listener is real.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:osms/core/api/auth_client.dart';
import 'package:osms/core/api/auth_client_io.dart';

class MemoryStore implements SessionStore {
  String? session;

  @override
  Future<String?> read() async => session;

  @override
  Future<void> write(String session) async => this.session = session;

  @override
  Future<void> delete() async => session = null;
}

final base = Uri.parse('http://auth.test');

/// The sign-in service: trades `one-time` for a session, knows that session.
final service = MockClient((request) async {
  switch (request.url.path) {
    case '/api/auth/one-time-token/verify':
      final ok = (jsonDecode(request.body) as Map)['token'] == 'one-time';
      return ok ? http.Response('{}', 200, headers: {'set-auth-token': 'session.sig'}) : http.Response('{}', 400);
    case '/api/auth/get-session':
      if (request.headers['Authorization'] != 'Bearer session.sig') return http.Response('null', 200);
      return http.Response(jsonEncode({'user': {'id': 'ada', 'email': 'ada@users.example', 'name': 'Ada'}}), 200);
    case '/api/auth/sign-out':
      return http.Response('{}', 200);
  }
  return http.Response('', 404);
});

/// A browser that finishes Google sign-in and is sent back with [result]
/// (`token=...` or `error=...`), the way the sign-in service redirects it.
OpenBrowser browserReturning(String? result, {void Function(Uri)? opened, bool firstWrongState = false}) {
  return (url) async {
    opened?.call(url);
    final returnTo = Uri.parse(url.queryParameters['return_to']!);
    Future<int> visit(Uri target) async {
      final request = await HttpClient().getUrl(target);
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    }

    if (firstWrongState) {
      final stranger = returnTo.replace(queryParameters: {'state': 'someone-else', 'token': 'stolen'});
      expect(await visit(stranger), HttpStatus.notFound);
    }
    if (result != null) {
      Future(() => visit(Uri.parse('$returnTo&$result')));
    }
    return true;
  };
}

NativeAuthClient client(OpenBrowser browser, MemoryStore store, {Duration timeout = const Duration(seconds: 5)}) =>
    NativeAuthClient(base, client: service, store: store, openBrowser: browser, timeout: timeout);

void main() {
  test('signs in through the browser and keeps the session in the Keychain', () async {
    final store = MemoryStore();
    Uri? opened;
    final auth = client(browserReturning('token=one-time', opened: (u) => opened = u), store);

    expect(await auth.signInWithGoogle(), isTrue);
    expect(store.session, 'session.sig');
    expect((await auth.currentUser())!.email, 'ada@users.example');

    expect(opened!.path, '/native/sign-in');
    expect(opened!.queryParameters['provider'], 'google');
    expect(
      opened!.queryParameters['return_to'],
      matches(RegExp(r'^http://127\.0\.0\.1:\d{4,5}/callback\?state=[A-Za-z0-9_-]{32}$')),
    );
  });

  test('ignores anything that comes back without its own state', () async {
    final store = MemoryStore();
    final auth = client(browserReturning('token=one-time', firstWrongState: true), store);
    await auth.signInWithGoogle();
    expect(store.session, 'session.sig');
  });

  test('says so when Google sign-in is cancelled', () async {
    final store = MemoryStore();
    final auth = client(browserReturning('error=access_denied'), store);
    await expectLater(
      auth.signInWithGoogle(),
      throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('cancelled'))),
    );
    expect(store.session, isNull);
  });

  test('a one-time token the service refuses signs nobody in', () async {
    final store = MemoryStore();
    final auth = client(browserReturning('token=forged'), store);
    await expectLater(auth.signInWithGoogle(), throwsA(isA<AuthException>()));
    expect(store.session, isNull);
  });

  test('gives up when the browser never comes back', () async {
    final store = MemoryStore();
    final auth = client(browserReturning(null), store, timeout: const Duration(milliseconds: 300));
    await expectLater(
      auth.signInWithGoogle(),
      throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('too long'))),
    );
  });

  test('says so when the browser can’t be opened', () async {
    final auth = client((_) async => false, MemoryStore());
    await expectLater(auth.signInWithGoogle(), throwsA(isA<AuthException>()));
  });

  test('signing out forgets the session', () async {
    final store = MemoryStore()..session = 'session.sig';
    await client(browserReturning(null), store).signOut();
    expect(store.session, isNull);
  });
}
