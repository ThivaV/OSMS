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

/// Which tab the page opens on. Both run the same flow: continuing signs a returning
/// reader in, or creates the account on first use.
enum SignInIntent { signIn, createAccount }

/// Signing in and creating an account, and nothing else: no examples, no demo. The
/// first page a signed-out visitor sees, on the web and on the Mac. No passwords: every
/// option goes through a provider. A new account continues to onboarding; a returning
/// reader, on any device, straight to their stories.
class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    this.providers = const [SignInProvider.google],
    this.status = SignInStatus.idle,
    this.pending,
    this.error,
    this.initialIntent = SignInIntent.signIn,
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
  final SignInIntent initialIntent;
  final ValueChanged<SignInProvider>? onContinue;
  final VoidCallback? onWhatWeKeep;

  /// Back to where the reader came from, when the page isn't the start (Widgetbook's flow).
  final VoidCallback? onBack;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  late SignInIntent _intent = widget.initialIntent;

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
                  child: _SignInPanel(page: widget, intent: _intent, onIntent: (i) => setState(() => _intent = i)),
                ),
              ),
            ),
            if (widget.onBack != null)
              Positioned(
                top: Space.sm,
                left: Space.sm,
                child: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: widget.onBack),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignInPanel extends StatelessWidget {
  const _SignInPanel({required this.page, required this.intent, required this.onIntent});

  final SignInPage page;
  final SignInIntent intent;
  final ValueChanged<SignInIntent> onIntent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final busy = page.status == SignInStatus.signingIn;
    final creating = intent == SignInIntent.createAccount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('OSMS', style: t.display),
        const SizedBox(height: Space.xs),
        Text('One story, many sources', style: t.reading.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.xxl),
        SegmentedButton<SignInIntent>(
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          segments: const [
            ButtonSegment(value: SignInIntent.signIn, label: Text('Sign in')),
            ButtonSegment(value: SignInIntent.createAccount, label: Text('Create account')),
          ],
          selected: {intent},
          onSelectionChanged: busy ? null : (s) => onIntent(s.first),
        ),
        const SizedBox(height: Space.xl),
        Text(creating ? 'Create your account' : 'Welcome back', style: t.title),
        const SizedBox(height: Space.sm),
        Text(
          creating
              ? 'Choose your own topics and sources. It takes about a minute.'
              : 'Sign in to your stories and your morning briefing.',
          style: t.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.xl),
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
        else
          for (final provider in page.providers) ...[
            _ProviderButton(
              provider: provider,
              intent: intent,
              waiting: busy && page.pending == provider,
              onPressed: busy || page.onContinue == null ? null : () => page.onContinue!(provider),
            ),
            const SizedBox(height: Space.sm),
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
  const _ProviderButton({required this.provider, required this.intent, required this.waiting, this.onPressed});

  final SignInProvider provider;
  final SignInIntent intent;
  final bool waiting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = waiting
        ? 'Finish in the ${provider.label} window…'
        : provider == SignInProvider.emailLink
        ? 'Email me a sign-in link'
        : intent == SignInIntent.createAccount
        ? 'Sign up with ${provider.label}'
        : 'Sign in with ${provider.label}';
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
