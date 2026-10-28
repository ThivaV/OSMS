import 'package:flutter/material.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/story_visual.dart';

enum SignInStatus {
  idle,

  /// Waiting for the provider's window to finish.
  signingIn,
  error,

  /// Sign-in is down. The demo still works.
  unavailable,
}

/// Which wording the page opens with. Both run the same flow: continuing signs
/// a returning reader in, or creates the account on first use.
enum SignInIntent { signIn, createAccount }

/// Sign in and sign up in one page. No passwords: every option goes through a
/// provider. A new account continues to onboarding; a returning reader to Today.
class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    this.providers = const [SignInProvider.google],
    this.status = SignInStatus.idle,
    this.pending,
    this.error,
    this.initialIntent = SignInIntent.signIn,
    this.onContinue,
    this.onTryDemo,
    this.onWhatWeKeep,
  });

  final List<SignInProvider> providers;
  final SignInStatus status;

  /// The provider being signed in with, while [status] is `signingIn`.
  final SignInProvider? pending;

  /// Shown while [status] is `error`.
  final String? error;
  final SignInIntent initialIntent;
  final ValueChanged<SignInProvider>? onContinue;
  final VoidCallback? onTryDemo;
  final VoidCallback? onWhatWeKeep;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  late SignInIntent _intent = widget.initialIntent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final panel = _SignInPanel(
      page: widget,
      intent: _intent,
      onSwitchIntent: () => setState(
        () => _intent = _intent == SignInIntent.signIn ? SignInIntent.createAccount : SignInIntent.signIn,
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (WindowSize.fromWidth(constraints.maxWidth) == WindowSize.desktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: c.surfaceMuted,
                      child: const Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(Space.xxxl),
                          child: _Brand(large: true),
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: Sizes.hairline),
                  SizedBox(
                    width: Sizes.signInPanelWidth,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(Space.xxl),
                        child: panel,
                      ),
                    ),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(Space.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Sizes.sheetMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Brand(large: false),
                      const SizedBox(height: Space.xxl),
                      panel,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Wordmark, the story-thread art and what OSMS does, in three lines.
class _Brand extends StatelessWidget {
  const _Brand({required this.large});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    const points = [
      (Icons.layers_outlined, 'Sixty items become seven stories', 'Articles, podcasts, videos and posts about the same event, together.'),
      (Icons.update_rounded, 'Only what changed', 'New facts since you last looked, and where sources disagree.'),
      (Icons.wb_twilight_rounded, 'A morning briefing', 'Your stories, read aloud, in English, Danish or Tamil.'),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Sizes.sheetMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OSMS', style: large ? t.display : t.title),
            const SizedBox(height: Space.xs),
            Text('One story, many sources', style: t.reading.copyWith(color: c.textSecondary)),
            SizedBox(height: large ? Space.xxl : Space.xl),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.lg),
              child: StoryVisual(seed: 7, threads: 12, aspectRatio: large ? 1.6 : 2.6),
            ),
            if (large) ...[
              const SizedBox(height: Space.xxl),
              for (final (icon, title, body) in points) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: Sizes.iconLg, color: c.textSecondary),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: t.subhead),
                          const SizedBox(height: Space.xxs),
                          Text(body, style: t.bodySmall.copyWith(color: c.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SignInPanel extends StatelessWidget {
  const _SignInPanel({required this.page, required this.intent, required this.onSwitchIntent});

  final SignInPage page;
  final SignInIntent intent;
  final VoidCallback onSwitchIntent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final busy = page.status == SignInStatus.signingIn;
    final unavailable = page.status == SignInStatus.unavailable;
    final creating = intent == SignInIntent.createAccount;
    final onlyGoogle = page.providers.length == 1 && page.providers.first == SignInProvider.google;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(creating ? 'Create your account' : 'Welcome back', style: t.title),
        const SizedBox(height: Space.sm),
        Text(
          creating
              ? 'Pick your own topics and sources. It takes about a minute.'
              : 'Sign in to your stories and your morning briefing.',
          style: t.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.xl),
        if (page.status == SignInStatus.error) ...[
          _ErrorNote(message: page.error ?? 'Something went wrong. Please try again.'),
          const SizedBox(height: Space.lg),
        ],
        if (unavailable)
          const QuietNote(
            icon: Icons.cloud_off_rounded,
            title: 'Sign-in is unavailable right now',
            body: 'You can still look around the demo. Your own sources need an account, so please try again later.',
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
          Text(
            onlyGoogle
                ? 'Continuing with Google signs you in, or creates your account if you’re new. '
                    'OSMS never sees your password.'
                : 'Continuing signs you in, or creates your account if you’re new. '
                    'OSMS never sees your password.',
            style: t.caption.copyWith(color: c.textTertiary),
          ),
        ],
        const SizedBox(height: Space.xl),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Text('or', style: t.caption.copyWith(color: c.textTertiary)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: Space.xl),
        SizedBox(
          height: Sizes.buttonHeight,
          child: unavailable
              ? FilledButton.icon(
                  onPressed: page.onTryDemo,
                  icon: const Icon(Icons.visibility_outlined, size: Sizes.iconMd),
                  label: const Text('Look around the demo'),
                )
              : OutlinedButton.icon(
                  onPressed: busy ? null : page.onTryDemo,
                  icon: const Icon(Icons.visibility_outlined, size: Sizes.iconMd),
                  label: const Text('Look around the demo first'),
                ),
        ),
        if (!unavailable) ...[
          const SizedBox(height: Space.lg),
          Center(
            child: TextButton(
              onPressed: busy ? null : onSwitchIntent,
              child: Text(creating ? 'Already have an account? Sign in' : 'New to OSMS? Create an account'),
            ),
          ),
        ],
        const SizedBox(height: Space.lg),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'OSMS keeps your email, your name and what you pick. '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: InkWell(
                  onTap: page.onWhatWeKeep,
                  child: Text(
                    'What OSMS keeps',
                    style: t.caption.copyWith(
                      color: c.text,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: c.textTertiary),
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
