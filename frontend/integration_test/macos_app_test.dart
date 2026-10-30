// The real macOS app, in its sandbox, against the real sign-in service and API.
// Needs both running (`make up`) and opens a window; `make test-macos` runs it.
//
// The signed-in part needs a development reader's session cookie, which
// `make test-macos` gets with a development sign-in link (local only). It stands in
// for Google: everything after "Google said yes" is the real thing.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:osms/app.dart';
import 'package:osms/core/api/auth_client_io.dart';
import 'package:osms/core/config/env.dart';

const sessionCookie = String.fromEnvironment('OSMS_TEST_SESSION_COOKIE');

/// Screenshots of what the app drew (no screen-recording permission needed), in the
/// app's sandbox container: ~/Library/Containers/io.github.thivav.osms/Data/tmp/osms-shots
final shots = Directory('${Directory.systemTemp.path}/osms-shots');
final frame = GlobalKey();

/// Pumps real frames until one of [finders] matches (the network is real), and says which.
Future<Finder> waitForAny(WidgetTester tester, List<Finder> finders, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) return finder;
    }
  }
  throw TestFailure('Timed out waiting for ${finders.join(' or ')}');
}

Future<void> waitFor(WidgetTester tester, Finder finder) => waitForAny(tester, [finder]);

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 500));
  final boundary = frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  shots.createSync(recursive: true);
  File('${shots.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  debugPrint('screenshot: ${shots.path}/$name.png');
}

Future<void> startApp(WidgetTester tester) =>
    tester.pumpWidget(ProviderScope(child: RepaintBoundary(key: frame, child: const OsmsApp())));

void go(WidgetTester tester, String path) => GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);

/// What the reader's browser does once Google has said yes: it lands on the sign-in
/// service's /native/done and is sent back to the app's loopback address.
OpenBrowser browserSignedInAs(String cookie) => (start) async {
  final http = HttpClient();
  Future<HttpClientResponse> get(Uri url, [String? cookies]) async {
    final request = await http.getUrl(url)..followRedirects = false;
    if (cookies != null) request.headers.set(HttpHeaders.cookieHeader, cookies);
    return request.close();
  }

  final started = await get(start);
  await started.drain<void>();
  final flow = started.headers[HttpHeaders.setCookieHeader]!
      .firstWhere((c) => c.startsWith('osms_native_flow='))
      .split(';')
      .first;
  final returnTo = start.queryParameters['return_to']!;
  final done = await get(Env.authUrl.replace(path: '/native/done', queryParameters: {'return_to': returnTo}), '$cookie; $flow');
  await done.drain<void>();
  final back = await get(Uri.parse(done.headers.value(HttpHeaders.locationHeader)!));
  await back.drain<void>();
  return true;
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed out: the demo, with Google sign-in on offer', (tester) async {
    await const KeychainStore().delete();
    await startApp(tester);
    // Only shown when the sandboxed app reached the sign-in service.
    await waitFor(tester, find.text('Create an account'));
    await shot(tester, '1-signed-out');
    await tester.tap(find.text('Create an account').first);
    await waitFor(tester, find.text('Continue with Google'));
    expect(find.text('Email me a sign-in link'), findsNothing, reason: 'email links are web-only');
    await shot(tester, '2-sign-in');
  });

  testWidgets('the sandbox lets the app keep a session in the Keychain and listen on 127.0.0.1', (tester) async {
    const store = KeychainStore();
    await store.write('probe');
    expect(await store.read(), 'probe');
    await store.delete();
    expect(await store.read(), isNull);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) => request.response
      ..write('ok')
      ..close());
    final response = await (await HttpClient().getUrl(Uri.parse('http://127.0.0.1:${server.port}/'))).close();
    expect(await response.transform(utf8.decoder).join(), 'ok');
    await server.close(force: true);
  });

  testWidgets(
    'signs in through the desktop hand-off, onboards, reaches Today, deletes the account',
    skip: sessionCookie.isEmpty,
    (tester) async {
      final client = NativeAuthClient(Env.authUrl, openBrowser: browserSignedInAs(sessionCookie));
      expect(await client.signInWithGoogle(), isTrue);

      await startApp(tester);
      final onboarding = find.text('Which language should OSMS write in?');
      // A new reader's Today is empty until OSMS has collected their sources' stories.
      final today = find.text('Your stories will appear here');
      // A test reader left over from a run that stopped early is already onboarded.
      if (await waitForAny(tester, [onboarding, today]) == onboarding) {
        await shot(tester, '3-onboarding');
        await tester.tap(find.text('Skip'));
      }
      await waitFor(tester, today);
      await shot(tester, '4-today');

      go(tester, '/settings');
      await waitFor(tester, find.text('Appearance'));
      await shot(tester, '5-settings');

      // Clean up: the test reader deletes their account, as a reader would.
      await tester.scrollUntilVisible(find.text('Delete my account'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Delete my account').first);
      await waitFor(tester, find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await waitFor(tester, find.text('You’re reading the demo'));
      expect(await const KeychainStore().read(), isNull);

      // The sign-in account is gone too: its session no longer works.
      final check = await HttpClient().getUrl(Env.authUrl.resolve('/api/auth/get-session'));
      check.headers.set(HttpHeaders.cookieHeader, sessionCookie);
      expect(await (await check.close()).transform(utf8.decoder).join(), 'null');
    },
  );
}
