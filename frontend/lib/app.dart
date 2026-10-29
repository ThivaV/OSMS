import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/env.dart';
import 'core/session/session.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/what_we_keep_page.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/sources/interests_screen.dart';

/// Where a reader may be. Signed out: everywhere but onboarding and interests (the
/// demo). Signed in but new: onboarding first. Returning: never back to sign-in.
String? redirectFor(Session? session, String path) {
  if (session == null) return null; // Still loading: the app shows its splash.
  final account = session.account;
  if (account == null) return const {'/onboarding', '/interests'}.contains(path) ? '/sign-in' : null;
  if (!account.onboarded) return const {'/onboarding', '/what-we-keep'}.contains(path) ? null : '/onboarding';
  return const {'/sign-in', '/onboarding'}.contains(path) ? '/' : null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final changed = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => changed.value++);
  final router = GoRouter(
    refreshListenable: changed,
    redirect: (context, state) => redirectFor(ref.read(sessionProvider).value, state.matchedLocation),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (_, state) => SignInScreen(createAccount: state.uri.queryParameters['intent'] == 'create'),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/interests', builder: (_, _) => const InterestsScreen()),
      GoRoute(
        path: '/what-we-keep',
        builder: (context, _) => WhatWeKeepPage(
          contactEmail: Env.privacyContact.isEmpty ? null : Env.privacyContact,
          onBack: () => context.go('/'),
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    changed.dispose();
  });
  return router;
});

/// Theme and routing. The appearance comes from the signed-in account, or from
/// Settings for a signed-out visitor.
class OsmsApp extends ConsumerStatefulWidget {
  const OsmsApp({super.key});

  @override
  ConsumerState<OsmsApp> createState() => _OsmsAppState();
}

class _OsmsAppState extends ConsumerState<OsmsApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    final router = ref.watch(routerProvider);
    final loaded = ref.watch(sessionProvider.select((s) => s.hasValue));

    // Problems while signed in (a setting that didn't save, a deletion that half
    // finished) show as a short note. Signed out, the sign-in page and the demo
    // banner say it themselves.
    ref.listen(sessionProvider, (previous, next) {
      final before = previous?.value;
      final message = next.value?.message;
      final wasOrIsSignedIn = (before?.signedIn ?? false) || (next.value?.signedIn ?? false);
      if (message != null && message != before?.message && wasOrIsSignedIn) {
        _messenger.currentState?.showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return MaterialApp.router(
      title: 'OSMS',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: AppTheme.forAppearance(appearance, Brightness.light),
      darkTheme: AppTheme.forAppearance(appearance, Brightness.dark),
      themeMode: appearance.mode,
      routerConfig: router,
      builder: (context, child) => loaded ? child! : const _Splash(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('OSMS', style: context.text.display),
            const SizedBox(height: Space.sm),
            Text('One story, many sources', style: context.text.body.copyWith(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
