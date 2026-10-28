import 'package:flutter/material.dart';
import 'package:osms/core/theme/app_theme.dart';
import 'package:osms/core/theme/appearance.dart';
import 'package:osms/core/theme/palettes.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import 'main.directories.g.dart';

void main() {
  runApp(const WidgetbookApp());
}

/// Viewports at the app's breakpoints: phone < 600, tablet 600–1024, desktop > 1024.
const _viewports = [
  ViewportData(name: 'Desktop · 1440', width: 1440, height: 900, pixelRatio: 2, platform: TargetPlatform.macOS),
  ViewportData(name: 'Tablet · 834', width: 834, height: 1112, pixelRatio: 2, platform: TargetPlatform.iOS),
  ViewportData(name: 'Phone · 390', width: 390, height: 844, pixelRatio: 3, platform: TargetPlatform.iOS),
];

@widgetbook.App()
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: directories,
      addons: [
        ViewportAddon(_viewports),
        MaterialThemeAddon(
          themes: [
            for (final palette in Palettes.all) ...[
              WidgetbookTheme(name: '${palette.name} · Light', data: AppTheme.build(palette, Brightness.light)),
              WidgetbookTheme(name: '${palette.name} · Dark', data: AppTheme.build(palette, Brightness.dark)),
            ],
            WidgetbookTheme(
              name: 'Folio · Pure black',
              data: AppTheme.build(Palettes.folio, Brightness.dark, const Appearance(pureBlack: true)),
            ),
          ],
        ),
        TextScaleAddon(min: 1, max: 2, divisions: 4),
      ],
    );
  }
}
