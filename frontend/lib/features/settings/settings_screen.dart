import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/config/languages.dart';
import '../../core/session/session.dart';
import '../../sample/sample_content.dart' as sample;
import '../../shared/widgets/story_card.dart';
import 'settings_page.dart';

/// Settings. Signed in, every change is saved to the account and follows the reader
/// to other devices; signed out, appearance changes last until the page closes.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(sessionProvider).requireValue.account;
    final session = ref.read(sessionProvider.notifier);

    void snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    return SettingsPage(
      appearance: ref.watch(appearanceProvider),
      onAppearanceChanged: session.updateAppearance,
      languages: appLanguages,
      language: account?.user.language ?? 'en',
      onLanguageChanged: account == null ? null : session.setLanguage,
      defaultLayout: account?.defaultLayout ?? StoryCardLayout.row,
      onDefaultLayoutChanged: account == null ? null : session.setDefaultLayout,
      user: account?.user,
      previewStory: sample.stories.first,
      onBack: () => context.go('/'),
      onWhatWeKeep: () => context.go('/what-we-keep'),
      onResearchInterests: account == null ? null : () => context.go('/interests'),
      onSignOut: account == null
          ? null
          : () async {
              await session.signOut();
              if (context.mounted) context.go('/');
            },
      onDeleteAccount: account == null
          ? null
          : () async {
              try {
                await session.deleteAccount();
                if (context.mounted) context.go('/');
              } on ApiException catch (e) {
                if (context.mounted) snack('Nothing was deleted. ${e.message}');
              }
            },
    );
  }
}
