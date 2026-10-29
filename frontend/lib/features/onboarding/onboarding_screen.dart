import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/session/account.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/section_header.dart';
import 'onboarding_flow.dart';

/// The first sign-in lands here. The topics and suggested sources come from the
/// seed source list, through the API; the picks are saved to the reader's account.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _saving = false;

  /// Pre-filled from the browser or system, when OSMS writes in that language.
  String _initialLanguage(OnboardingOptions options) {
    final system = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return options.languages.any((l) => l.code == system) ? system : 'en';
  }

  Future<void> _done(OnboardingPicks picks) async {
    setState(() => _saving = true);
    try {
      await ref.read(sessionProvider.notifier).completeOnboarding(picks);
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(onboardingOptionsProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: Center(
            child: switch (options) {
              AsyncData(:final value) => AbsorbPointer(
                absorbing: _saving,
                child: Onboarding(
                  languages: value.languages,
                  topics: value.topics,
                  suggestions: value.suggestions,
                  initialLanguage: _initialLanguage(value),
                  onDone: _done,
                ),
              ),
              AsyncError(:final error) => ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Sizes.sheetMaxWidth),
                child: QuietNote(
                  icon: Icons.cloud_off_rounded,
                  title: 'Couldn’t load the topics',
                  body: error is ApiException ? error.message : 'OSMS is unavailable right now.',
                  action: OutlinedButton(
                    onPressed: () => ref.invalidate(onboardingOptionsProvider),
                    child: const Text('Try again'),
                  ),
                ),
              ),
              _ => const Padding(padding: EdgeInsets.all(Space.xxl), child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }
}
