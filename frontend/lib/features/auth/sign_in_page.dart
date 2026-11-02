import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/section_header.dart';

enum SignInStatus {
  idle,

  /// Waiting for the provider's window to finish.
  signingIn,
  error,

  /// Sign-in is down. The demo still works.
  unavailable,
}

/// Sign in and sign up in one page, and nothing else on it. No passwords: every option
/// goes through a provider. A new account continues to onboarding; a returning reader,
/// on any device, straight to their stories.
class SignInPage extends StatelessWidget {
  const SignInPage({
    super.key,
    this.providers = const [SignInProvider.google],
    this.status = SignInStatus.idle,
    this.pending,
    this.error,
    this.onContinue,
    this.onWhatWeKeep,
    this.onBack,
  });

  final List<SignInProvider> providers;
  final SignInStatus status;

  /// The provider being signed in with, while [status] is `signingIn`.
  final SignInProvider? pending;

  /// Shown while [status] is `error`.
  final String? error;
  final ValueChanged<SignInProvider>? onContinue;
  final VoidCallback? onWhatWeKeep;

  /// Back to where the reader came from (the desktop app has no browser back button).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Sizes.signInPanelWidth),
                  child: _SignInPanel(page: this),
                ),
              ),
            ),
            if (onBack != null)
              Positioned(
                top: Space.sm,
                left: Space.sm,
                child: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: onBack),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignInPanel extends StatelessWidget {
  const _SignInPanel({required this.page});

  final SignInPage page;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final busy = page.status == SignInStatus.signingIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('OSMS', style: t.display),
        const SizedBox(height: Space.xs),
        Text('One story, many sources', style: t.reading.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.xxl),
        Text('Sign in', style: t.title),
        const SizedBox(height: Space.lg),
        if (page.status == SignInStatus.error) ...[
          _ErrorNote(message: page.error ?? 'Something went wrong. Please try again.'),
          const SizedBox(height: Space.lg),
        ],
        if (page.status == SignInStatus.unavailable)
          const QuietNote(
            icon: Icons.cloud_off_rounded,
            title: 'Sign-in is unavailable right now',
            body: 'Please try again in a little while.',
          )
        else ...[
          for (final provider in page.providers) ...[
            _ProviderButton(
              provider: provider,
              waiting: busy && page.pending == provider,
              onPressed: busy || page.onContinue == null ? null : () => page.onContinue!(provider),
            ),
            const SizedBox(height: Space.sm),
          ],
          const SizedBox(height: Space.xs),
          Text('New here? This creates your account.', style: t.caption.copyWith(color: c.textTertiary)),
        ],
        const SizedBox(height: Space.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            link: true,
            child: InkWell(
              onTap: page.onWhatWeKeep,
              child: Text(
                'What OSMS keeps',
                style: t.caption.copyWith(color: c.text, decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({required this.provider, required this.waiting, this.onPressed});

  final SignInProvider provider;
  final bool waiting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = waiting
        ? 'Finish in the ${provider.label} window…'
        : provider == SignInProvider.emailLink
        ? 'Email me a sign-in link'
        : 'Continue with ${provider.label}';
    return SizedBox(
      height: Sizes.buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: c.surface,
          foregroundColor: c.text,
          side: BorderSide(color: c.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (waiting)
              SizedBox(
                width: Sizes.iconMd,
                height: Sizes.iconMd,
                child: CircularProgressIndicator(strokeWidth: Sizes.focusRing, color: c.textSecondary),
              )
            else
              _ProviderMark(provider: provider),
            const SizedBox(width: Space.md),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// PLACEHOLDER. Release builds use each provider's official mark and follow
/// its sign-in branding guidelines (Google's in particular). Never draw an
/// imitation of a provider's logo.
class _ProviderMark extends StatelessWidget {
  const _ProviderMark({required this.provider});

  final SignInProvider provider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (provider == SignInProvider.emailLink) {
      return Icon(Icons.mail_outline_rounded, size: Sizes.iconMd, color: c.textSecondary);
    }
    return Container(
      width: Sizes.iconMd + Space.xxs,
      height: Sizes.iconMd + Space.xxs,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.sm / 2),
        border: Border.all(color: c.borderStrong),
      ),
      child: Text(
        provider.label.characters.first,
        style: context.text.caption.copyWith(color: c.textTertiary, fontWeight: FontWeight.w700, height: 1),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: c.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: Sizes.iconMd, color: c.error),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign-in didn’t finish', style: t.subhead),
                  const SizedBox(height: Space.xxs),
                  Text(message, style: t.bodySmall.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
