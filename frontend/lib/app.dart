import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/appearance.dart';
import 'core/theme/tokens.dart';

/// Theme and routing. Routing (go_router) arrives with the real screens; the
/// appearance will come from the signed-in account.
class OsmsApp extends StatelessWidget {
  const OsmsApp({super.key, this.appearance = const Appearance()});

  final Appearance appearance;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forAppearance(appearance, Brightness.light),
      darkTheme: AppTheme.forAppearance(appearance, Brightness.dark),
      themeMode: appearance.mode,
      home: const _ComingSoon(),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('OSMS', style: context.text.display),
            const SizedBox(height: Space.sm),
            Text(
              'One story, many sources. The components live in Widgetbook for now.',
              style: context.text.body.copyWith(color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
