import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/source_chip.dart';

/// The account, at the foot of the sidebar. Signed out, it is the way in.
class AccountRow extends StatelessWidget {
  const AccountRow({super.key, this.user, this.onSignIn, this.onSettings, this.onWhatWeKeep, this.onSignOut});

  /// Null while signed out (reading the demo).
  final User? user;
  final VoidCallback? onSignIn;
  final VoidCallback? onSettings;
  final VoidCallback? onWhatWeKeep;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final user = this.user;

    if (user == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: onSignIn ?? () {},
            icon: const Icon(Icons.login_rounded, size: Sizes.iconMd),
            label: const Text('Sign in'),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'You’re reading the demo',
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: c.textTertiary),
          ),
        ],
      );
    }

    return Row(
      children: [
        MonogramAvatar(id: user.id, name: user.shownName),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.shownName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(color: c.textTertiary),
              ),
            ],
          ),
        ),
        PopupMenuButton<VoidCallback?>(
          tooltip: 'Account',
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (action) => action?.call(),
          itemBuilder: (context) => [
            PopupMenuItem(value: onSettings, child: const Text('Settings')),
            PopupMenuItem(value: onWhatWeKeep, child: const Text('What OSMS keeps')),
            const PopupMenuDivider(),
            PopupMenuItem(value: onSignOut, child: const Text('Sign out')),
          ],
        ),
      ],
    );
  }
}
