// The main screens in every theme (light, dark and pure black) at every size,
// so a new palette can't break a layout or hide a widget without notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osms/core/layout/three_pane_layout.dart';
import 'package:osms/core/theme/app_theme.dart';
import 'package:osms/core/theme/appearance.dart';
import 'package:osms/core/theme/palettes.dart';
import 'package:osms/features/auth/sign_in_page.dart';
import 'package:osms/features/settings/settings_page.dart';
import 'package:osms/features/sources/sources_sidebar.dart';
import 'package:osms/features/stories/story_list.dart';
import 'package:osms/features/story_detail/story_detail_view.dart';
import 'package:osms_widgetbook/fixtures/fixtures.dart' as fx;

const _sizes = {'phone': Size(390, 844), 'tablet': Size(834, 1112), 'desktop': Size(1440, 900)};

final Map<String, Widget Function()> _screens = {
  'shell': () => ThreePaneLayout(
    sidebar: SourcesSidebar(topics: fx.topics, sources: fx.followedSources, briefing: fx.briefing, user: fx.user),
    list: StoryList(stories: fx.stories, selectedId: fx.halcyon.id, onLayoutChanged: (_) {}),
    detail: StoryDetailView(story: fx.halcyon),
    onBack: () {},
  ),
  'sign in': () => SignInPage(onContinue: (_) {}, onTryDemo: () {}),
  'settings': () => SettingsPage(
    appearance: const Appearance(),
    onAppearanceChanged: (_) {},
    languages: fx.languages,
    user: fx.user,
    previewStory: fx.halcyon,
  ),
};

void main() {
  final themes = <String, ThemeData>{
    for (final p in Palettes.all) ...{
      '${p.name} light': AppTheme.build(p, Brightness.light),
      '${p.name} dark': AppTheme.build(p, Brightness.dark),
      '${p.name} pure black': AppTheme.build(p, Brightness.dark, const Appearance(pureBlack: true)),
    },
  };

  for (final MapEntry(key: themeName, value: theme) in themes.entries) {
    for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
      for (final MapEntry(key: screen, value: build) in _screens.entries) {
        testWidgets('$themeName · $sizeName · $screen', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(MaterialApp(theme: theme, home: build()));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
