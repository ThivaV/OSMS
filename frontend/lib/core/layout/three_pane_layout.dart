import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'breakpoints.dart';

/// The app shell.
/// - Desktop: sources | stories | story detail (or [overview] when none is open).
/// - Tablet: stories | detail; sources in a drawer.
/// - Phone: one pane at a time, with a floating tab bar ([phoneNav]).
///
/// [floatingPlayer] floats over the bottom of the story list (above the tab
/// bar on phones). Scrolling content passes under it.
class ThreePaneLayout extends StatelessWidget {
  const ThreePaneLayout({
    super.key,
    required this.sidebar,
    required this.list,
    this.detail,
    this.overview,
    this.floatingPlayer,
    this.phoneNav,
    this.phoneBody,
    this.title = 'OSMS',
    this.onBack,
  });

  final Widget sidebar;
  final Widget list;

  /// The selected story. On phones it replaces everything else while set.
  final Widget? detail;

  /// Shown in the reading pane when no story is open (desktop and tablet).
  final Widget? overview;
  final Widget? floatingPlayer;

  /// Phone only: the tab bar, and the page for a tab other than the list.
  final Widget? phoneNav;
  final Widget? phoneBody;
  final String title;

  /// Phone only: leave the detail pane.
  final VoidCallback? onBack;

  /// Room to leave at the bottom of scrolling lists for floating bars.
  static const floatingInset = Space.xxxl * 2.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = WindowSize.fromWidth(constraints.maxWidth);
        final c = context.colors;
        final reading = AnimatedSwitcher(
          duration: Motion.motionOf(context, Motion.pane),
          switchInCurve: Motion.standard,
          child: detail ?? overview ?? const _NoSelection(),
        );

        Widget withPlayer(Widget child) => floatingPlayer == null
            ? child
            : Stack(
                children: [
                  Positioned.fill(child: child),
                  Positioned(left: Space.lg, right: Space.lg, bottom: Space.lg, child: Center(child: floatingPlayer)),
                ],
              );

        // With nothing open, the overview takes the list and reading panes;
        // opening a story brings back the panes.
        final home = detail == null && overview != null;

        return switch (size) {
          WindowSize.desktop => Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: Sizes.sidebarWidth,
                  child: ColoredBox(color: c.surfaceMuted, child: sidebar),
                ),
                const VerticalDivider(width: Sizes.hairline),
                if (home)
                  Expanded(child: withPlayer(reading))
                else ...[
                  SizedBox(
                    width: Sizes.listWidth,
                    child: ColoredBox(color: c.surface, child: withPlayer(list)),
                  ),
                  const VerticalDivider(width: Sizes.hairline),
                  Expanded(child: reading),
                ],
              ],
            ),
          ),
          WindowSize.tablet => Scaffold(
            appBar: AppBar(title: Text(title)),
            drawer: Drawer(child: SafeArea(child: sidebar)),
            body: home
                ? withPlayer(reading)
                : Row(
                    children: [
                      SizedBox(
                        width: Sizes.listWidthTablet,
                        child: ColoredBox(color: c.surface, child: withPlayer(list)),
                      ),
                      const VerticalDivider(width: Sizes.hairline),
                      Expanded(child: detail ?? const _NoSelection()),
                    ],
                  ),
          ),
          WindowSize.phone => Scaffold(
            appBar: AppBar(
              title: Text(title),
              leading: detail != null && onBack != null
                  ? IconButton(tooltip: 'Back', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded))
                  : null,
            ),
            drawer: detail == null && phoneNav == null ? Drawer(child: SafeArea(child: sidebar)) : null,
            body: detail != null
                ? ColoredBox(color: c.surface, child: detail)
                : Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: c.surface, child: phoneBody ?? list)),
                      Positioned(
                        left: Space.lg,
                        right: Space.lg,
                        bottom: Space.lg,
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (floatingPlayer != null) ...[
                                Center(child: floatingPlayer),
                                const SizedBox(height: Space.sm),
                              ],
                              ?phoneNav,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        };
      },
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_outlined, size: Sizes.iconXl, color: c.textTertiary),
          const SizedBox(height: Space.md),
          Text('Pick a story to read', style: context.text.subhead.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}
