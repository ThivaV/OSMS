import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// What an empty Today says. Signed in, OSMS shows only the reader's own stories, so a
/// new reader starts here: with no sources, how to choose some; with sources, that the
/// first stories appear once they are collected.
abstract final class NoStories {
  static const title = 'Your stories will appear here';

  /// The line under the greeting.
  static String summary(int sourceCount) =>
      sourceCount == 0 ? 'No stories yet. Choose a few topics or sources to begin.' : 'No stories yet.';

  static String body(int sourceCount) => switch (sourceCount) {
    0 => 'Choose a few topics and sources, and OSMS groups everything they publish about the same event into one story.',
    1 => 'The first stories from your source appear here once OSMS has collected them.',
    _ => 'The first stories from your $sourceCount sources appear here once OSMS has collected them.',
  };
}

/// The empty state's buttons. Each appears only when it can do something.
class NoStoriesActions extends StatelessWidget {
  const NoStoriesActions({super.key, this.onChooseSources, this.onAddSource});

  final VoidCallback? onChooseSources;
  final VoidCallback? onAddSource;

  bool get hasActions => onChooseSources != null || onAddSource != null;

  @override
  Widget build(BuildContext context) {
    final choose = onChooseSources;
    final add = onAddSource;
    const addIcon = Icon(Icons.add_rounded, size: Sizes.iconMd);
    const addLabel = Text('Add a source');
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        if (choose != null)
          FilledButton.icon(
            onPressed: choose,
            icon: const Icon(Icons.tune_rounded, size: Sizes.iconMd),
            label: const Text('Choose topics and sources'),
          ),
        if (add != null)
          choose == null
              ? FilledButton.icon(onPressed: add, icon: addIcon, label: addLabel)
              : TextButton.icon(onPressed: add, icon: addIcon, label: addLabel),
      ],
    );
  }
}
