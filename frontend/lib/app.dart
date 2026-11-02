import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Where a reader may be. Signed out: `/` is the sign-in and sign-up page, the demo is at
/// `/demo`, and everywhere else but onboarding and interests is open. Signed in but new:
/// onboarding first. Returning: `/` is Today, never the demo, and onboarding again only
/// to choose topics and sources (an empty Today offers it).
String? redirectFor(Session? session, String path) {
  if (session == null) return null; // Still loading: the app shows its splash.
  final account = session.account;
  if (account == null) return const {'/onboarding', '/interests'}.contains(path) ? '/' : null;
  if (!account.onboarded) return const {'/onboarding', '/what-we-keep'}.contains(path) ? null : '/onboarding';
  return path == '/demo' ? '/' : null;
}

/// `/`: the reader's Today, or the sign-in and sign-up page while signed out.
class _Start extends ConsumerWidget {
  const _Start({required this.createAccount});

  final bool createAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(sessionProvider.select((s) => s.value?.signedIn ?? false))
      ? const HomeScreen()
      : SignInScreen(key: ValueKey(createAccount), createAccount: createAccount);
}

final routerProvider = Provider<GoRouter>((ref) {
  final changed = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => changed.value++);
  final router = GoRouter(
    refreshListenable: changed,
    redirect: (context, state) => redirectFor(ref.read(sessionProvider).value, state.matchedLocation),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) => _Start(createAccount: state.uri.queryParameters['intent'] == 'create'),
      ),
      // Older links: the page lives at `/` now.
      GoRoute(path: '/sign-in', redirect: (_, state) => state.uri.replace(path: '/').toString()),
      GoRoute(path: '/demo', builder: (_, _) => const HomeScreen()),
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
      builder: (context, child) {
        final page = loaded ? child! : const _Splash();
        return _onMacOS ? _MacMenus(router: router, child: page) : page;
      },
    );
  }
}

bool get _onMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// The macOS menu bar: the app menu with a working Settings… (⌘,), and a Window menu.
class _MacMenus extends StatelessWidget {
  const _MacMenus({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'OSMS',
          menus: [
            const PlatformMenuItemGroup(
              members: [PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about)],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Settings…',
                  shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
                  onSelected: () => router.go('/settings'),
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hideOtherApplications),
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.showAllApplications),
              ],
            ),
            const PlatformMenuItemGroup(members: [PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit)]),
          ],
        ),
        const PlatformMenu(
          label: 'Window',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.minimizeWindow),
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.zoomWindow),
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.toggleFullScreen),
              ],
            ),
          ],
        ),
      ],
      child: child,
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
