import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Above the story list while signed out: this is the demo, and how to get
/// your own. Judges can keep reading without an account.
class DemoBanner extends StatelessWidget {
  const DemoBanner({
    super.key,
    this.signInAvailable = true,
    this.samples = false,
    this.sampleEpisodes = false,
    this.onSignIn,
  });

  final bool signInAvailable;

  /// The demo's stories are invented samples, until OSMS collects real ones. Invented
  /// stories never pass for real ones, so the banner says so.
  final bool samples;

  /// The demo's podcast episodes are invented too, with stand-in music so the player
  /// can be tried. Shown on Listen, where they appear.
  final bool sampleEpisodes;

  /// One way in: signing in creates the account for someone new, and takes a reader who
  /// has one, on any device, straight to their stories.
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
            if (sampleEpisodes) 'Its podcast episodes are invented samples, with stand-in music so you can try the player.',
            signInAvailable
                ? 'Sign in to choose your own topics and sources. New here? Signing in creates your account.'
                : 'Sign-in is unavailable right now. You can keep reading the demo.',
          ].join(' '),
          style: t.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    );
    final actions = FilledButton(onPressed: onSignIn ?? () {}, child: const Text('Sign in'));

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
