import 'package:flutter/material.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/core/theme/tokens.dart';
import 'package:osms/features/auth/account_row.dart';
import 'package:osms/features/auth/demo_banner.dart';
import 'package:osms/features/auth/sign_in_page.dart';
import 'package:osms/features/auth/what_we_keep_page.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;
import 'frame.dart';

/// Large text, to check the extreme cases also hold up for readers who need it.
Widget _largeText(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
    child: child,
  ),
);

// ── Sign in / create account ─────────────────────────────────────────────────

@widgetbook.UseCase(name: 'Normal', type: SignInPage, path: '[Accounts]')
Widget signInNormal(BuildContext context) {
  final intent = context.knobs.object.segmented(
    label: 'Opens as',
    options: SignInIntent.values,
    labelBuilder: (i) => i == SignInIntent.signIn ? 'Sign in' : 'Create account',
  );
  final status = context.knobs.object.dropdown(
    label: 'State',
    options: const [SignInStatus.idle, SignInStatus.signingIn, SignInStatus.error],
    labelBuilder: (s) => s.name,
  );
  final allProviders = context.knobs.boolean(label: 'All providers (post-hackathon)');
  return SignInPage(
    key: ValueKey((intent, status)),
    initialIntent: intent,
    status: status,
    pending: SignInProvider.google,
    error: fx.popupBlocked,
    providers: allProviders ? fx.allSignInProviders : const [SignInProvider.google],
    onContinue: (_) {},
    onTryDemo: () {},
    onWhatWeKeep: () {},
  );
}

@widgetbook.UseCase(name: 'Empty', type: SignInPage, path: '[Accounts]')
Widget signInEmpty(BuildContext context) =>
    SignInPage(status: SignInStatus.unavailable, onTryDemo: () {}, onWhatWeKeep: () {});

@widgetbook.UseCase(name: 'Extreme content', type: SignInPage, path: '[Accounts]')
Widget signInExtreme(BuildContext context) => _largeText(
  SignInPage(
    status: SignInStatus.error,
    error: fx.signedUpElsewhere,
    providers: fx.allSignInProviders,
    initialIntent: SignInIntent.createAccount,
    onContinue: (_) {},
    onTryDemo: () {},
    onWhatWeKeep: () {},
  ),
);

// ── What OSMS keeps ──────────────────────────────────────────────────────────

@widgetbook.UseCase(name: 'Normal', type: WhatWeKeepPage, path: '[Accounts]')
Widget whatWeKeepNormal(BuildContext context) => WhatWeKeepPage(contactEmail: fx.privacyContact, onBack: () {});

@widgetbook.UseCase(name: 'Empty', type: WhatWeKeepPage, path: '[Accounts]')
Widget whatWeKeepEmpty(BuildContext context) => const WhatWeKeepPage();

@widgetbook.UseCase(name: 'Extreme content', type: WhatWeKeepPage, path: '[Accounts]')
Widget whatWeKeepExtreme(BuildContext context) =>
    _largeText(WhatWeKeepPage(contactEmail: fx.longUser.email, onBack: () {}));

// ── Account row (sidebar foot) ───────────────────────────────────────────────

const _sidebarWidth = Sizes.sidebarWidth;

@widgetbook.UseCase(name: 'Normal', type: AccountRow, path: '[Accounts]')
Widget accountNormal(BuildContext context) => Frame(
  maxWidth: _sidebarWidth,
  child: AccountRow(user: fx.user, onSettings: () {}, onWhatWeKeep: () {}, onSignOut: () {}),
);

@widgetbook.UseCase(name: 'Empty', type: AccountRow, path: '[Accounts]')
Widget accountEmpty(BuildContext context) => Frame(maxWidth: _sidebarWidth, child: AccountRow(onSignIn: () {}));

@widgetbook.UseCase(name: 'Extreme content', type: AccountRow, path: '[Accounts]')
Widget accountExtreme(BuildContext context) => Frame(
  maxWidth: _sidebarWidth,
  child: AccountRow(user: fx.longUser, onSettings: () {}, onWhatWeKeep: () {}, onSignOut: () {}),
);

// ── Demo banner ──────────────────────────────────────────────────────────────

@widgetbook.UseCase(name: 'Normal', type: DemoBanner, path: '[Accounts]')
Widget demoBannerNormal(BuildContext context) =>
    Frame(child: DemoBanner(onCreateAccount: () {}, onSignIn: () {}));

@widgetbook.UseCase(name: 'Empty', type: DemoBanner, path: '[Accounts]')
Widget demoBannerEmpty(BuildContext context) => const Frame(child: DemoBanner(signInAvailable: false));

@widgetbook.UseCase(name: 'Extreme content', type: DemoBanner, path: '[Accounts]')
Widget demoBannerExtreme(BuildContext context) =>
    _largeText(Frame(child: DemoBanner(onCreateAccount: () {}, onSignIn: () {})));
