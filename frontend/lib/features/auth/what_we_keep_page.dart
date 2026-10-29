import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// "What OSMS keeps": the short page linked from sign-in. Plain words, no
/// legalese. The wording still needs a proper privacy review before launch.
class WhatWeKeepPage extends StatelessWidget {
  const WhatWeKeepPage({super.key, this.contactEmail, this.onBack});

  final String? contactEmail;
  final VoidCallback? onBack;

  static const _sections = [
    (
      'What OSMS keeps',
      [
        (Icons.badge_outlined, 'Your email and name', 'From Google, so OSMS knows it’s you when you sign in.'),
        (Icons.tune_rounded, 'Your language, topics and kinds of source', 'To choose and summarise your stories.'),
        (Icons.science_outlined, 'Your research interests', 'The keywords and arXiv categories you follow, to find new papers.'),
        (Icons.rss_feed_rounded, 'The sources you follow', 'So OSMS collects what they publish.'),
        (Icons.bookmark_outline_rounded, 'What you have read and saved', 'So it can show what’s new since you last looked.'),
        (Icons.wb_twilight_rounded, 'Your morning briefings', 'So you can play them again.'),
      ],
    ),
    (
      'What OSMS never does',
      [
        (Icons.block_rounded, 'Ask for a password', 'Google handles sign-in. OSMS never sees your password.'),
        (Icons.block_rounded, 'Read your mailbox, contacts or location', 'It doesn’t ask for them.'),
        (Icons.block_rounded, 'Show ads or run tracking scripts', 'None, anywhere in the app.'),
        (Icons.block_rounded, 'Profile you', 'What you read only ranks your own stories.'),
      ],
    ),
    (
      'Who else handles it',
      [
        (Icons.lock_outline_rounded, 'Google (Firebase Authentication)', 'Runs sign-in and stores your email and account id.'),
        (
          Icons.memory_rounded,
          'Meta’s AI models',
          'Read story content to write summaries and briefings, and your research keywords to suggest related '
              'terms, without being told whose they are. Never your email, name or reading history.',
        ),
        (Icons.science_outlined, 'arXiv', 'Receives the search words from your research interests, never your name or account.'),
      ],
    ),
    (
      'Leaving',
      [
        (
          Icons.delete_outline_rounded,
          'Delete your account at any time',
          'Settings → Delete my account removes everything above. Public stories and sources stay, because '
              'they aren’t yours.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      appBar: AppBar(
        title: const Text('What OSMS keeps'),
        leading: onBack == null
            ? null
            : IconButton(tooltip: 'Back', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.readingWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('What OSMS keeps, and why', style: t.title),
                const SizedBox(height: Space.sm),
                Text('The short version, in plain words.', style: t.body.copyWith(color: c.textSecondary)),
                for (final (heading, rows) in _sections) ...[
                  const SizedBox(height: Space.xxl),
                  Semantics(header: true, child: Text(heading, style: t.subhead)),
                  const SizedBox(height: Space.md),
                  Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      children: [
                        for (final (i, (icon, title, body)) in rows.indexed) ...[
                          if (i > 0) const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(Space.lg),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, size: Sizes.iconMd, color: c.textSecondary),
                                const SizedBox(width: Space.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: t.body.copyWith(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: Space.xxs),
                                      Text(body, style: t.bodySmall.copyWith(color: c.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (contactEmail != null) ...[
                  const SizedBox(height: Space.xxl),
                  Text('Questions? Write to $contactEmail.', style: t.bodySmall.copyWith(color: c.textSecondary)),
                ],
                const SizedBox(height: Space.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
