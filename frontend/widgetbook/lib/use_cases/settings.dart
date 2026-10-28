import 'package:flutter/material.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/core/theme/app_theme.dart';
import 'package:osms/core/theme/appearance.dart';
import 'package:osms/core/theme/palettes.dart';
import 'package:osms/core/theme/tokens.dart';
import 'package:osms/features/settings/settings_page.dart';
import 'package:osms/features/settings/theme_picker.dart';
import 'package:osms/shared/widgets/story_card.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;
import 'frame.dart';

/// Settings that re-theme themselves: pick a theme, mode, font or size and the
/// whole preview follows. "System" follows the theme chosen in the addon.
class _LiveSettings extends StatefulWidget {
  const _LiveSettings({this.user, this.initial = const Appearance()});

  final User? user;
  final Appearance initial;

  @override
  State<_LiveSettings> createState() => _LiveSettingsState();
}

class _LiveSettingsState extends State<_LiveSettings> {
  late Appearance _appearance = widget.initial;
  String _language = 'en';
  StoryCardLayout _layout = StoryCardLayout.row;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).brightness;
    return Theme(
      data: AppTheme.forAppearance(_appearance, _appearance.brightnessFor(platform)),
      child: SettingsPage(
        appearance: _appearance,
        onAppearanceChanged: (a) => setState(() => _appearance = a),
        languages: fx.languages,
        language: _language,
        onLanguageChanged: (l) => setState(() => _language = l),
        defaultLayout: _layout,
        onDefaultLayoutChanged: (l) => setState(() => _layout = l),
        user: widget.user,
        previewStory: fx.halcyon,
        onBack: () {},
        onWhatWeKeep: () {},
        onSignOut: () {},
        onDeleteAccount: () {},
      ),
    );
  }
}

@widgetbook.UseCase(name: 'Normal', type: SettingsPage, path: '[Accounts]')
Widget settingsNormal(BuildContext context) => const _LiveSettings(user: fx.user);

@widgetbook.UseCase(name: 'Empty', type: SettingsPage, path: '[Accounts]')
Widget settingsEmpty(BuildContext context) => const _LiveSettings();

@widgetbook.UseCase(name: 'Extreme content', type: SettingsPage, path: '[Accounts]')
Widget settingsExtreme(BuildContext context) => const _LiveSettings(
  user: fx.longUser,
  initial: Appearance(paletteId: 'nordlys', mode: ThemeMode.dark, pureBlack: true, readingScale: 1.4),
);

// ── Theme picker on its own ──────────────────────────────────────────────────

class _LivePicker extends StatefulWidget {
  const _LivePicker();

  @override
  State<_LivePicker> createState() => _LivePickerState();
}

class _LivePickerState extends State<_LivePicker> {
  String _selected = Palettes.folio.id;

  @override
  Widget build(BuildContext context) => ThemePicker(
    palettes: Palettes.all,
    selectedId: _selected,
    brightness: Theme.of(context).brightness,
    onSelect: (p) => setState(() => _selected = p.id),
  );
}

@widgetbook.UseCase(name: 'Normal', type: ThemePicker, path: '[Foundations]')
Widget themePickerNormal(BuildContext context) => const Frame(maxWidth: Sizes.readingWidth, child: _LivePicker());

@widgetbook.UseCase(name: 'Empty', type: ThemePicker, path: '[Foundations]')
Widget themePickerEmpty(BuildContext context) => Frame(
  maxWidth: Sizes.readingWidth,
  child: ThemePicker(
    palettes: const [Palettes.folio],
    selectedId: Palettes.folio.id,
    brightness: Theme.of(context).brightness,
    onSelect: (_) {},
  ),
);

@widgetbook.UseCase(name: 'Extreme content', type: ThemePicker, path: '[Foundations]')
Widget themePickerExtreme(BuildContext context) => Frame(
  maxWidth: Sizes.readingWidth,
  child: Variants(
    children: {
      'Every theme, light': ThemePicker(
        palettes: Palettes.all,
        selectedId: 'fjord',
        brightness: Brightness.light,
        onSelect: (_) {},
      ),
      'Every theme, dark': ThemePicker(
        palettes: Palettes.all,
        selectedId: 'nordlys',
        brightness: Brightness.dark,
        onSelect: (_) {},
      ),
    },
  ),
);
