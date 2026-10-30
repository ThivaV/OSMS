import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Above the story list while signed out: this is the demo, and how to get
/// your own. Judges can keep reading without an account.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, this.signInAvailable = true, this.samples = false, this.onCreateAccount, this.onSignIn});

  final bool signInAvailable;

  /// The demo's stories are invented samples, until OSMS collects real ones. Invented
  /// stories never pass for real ones, so the banner says so.
  final bool samples;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('You’re reading the demo', style: t.subhead),
        const SizedBox(height: Space.xxs),
        Text(
          [
            if (samples) 'Its stories are invented samples until OSMS starts collecting real ones.',
            signInAvailable
                ? 'Create an account to choose your own topics and sources. It takes about a minute.'
                : 'Sign-in is unavailable right now. You can keep reading the demo.',
          ].join(' '),
          style: t.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    );
    final actions = Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        FilledButton(onPressed: onCreateAccount ?? () {}, child: const Text('Create an account')),
        TextButton(onPressed: onSignIn ?? () {}, child: const Text('Sign in')),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, size: Sizes.iconLg, color: c.textSecondary),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                if (signInAvailable) ...[const SizedBox(height: Space.md), actions],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
