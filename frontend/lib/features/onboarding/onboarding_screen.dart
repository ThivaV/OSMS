import 'dart:async';

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
/// Setting up once is enough: finished on another device meanwhile, this one moves on.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with WidgetsBindingObserver {
  bool _saving = false;

  /// A new account setting up, not a reader changing their picks: only then can another
  /// device finish it for this one.
  late final bool _firstSetup = !(ref.read(sessionProvider).value?.account?.onboarded ?? false);
  Timer? _check;

  SessionController get _session => ref.read(sessionProvider.notifier);

  @override
  void initState() {
    super.initState();
    if (!_firstSetup) return;
    WidgetsBinding.instance.addObserver(this);
    _check = Timer.periodic(const Duration(seconds: 10), (_) => _session.refreshAccount());
  }

  @override
  void dispose() {
    _check?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_session.refreshAccount());
  }

  /// Pre-filled from the browser or system, when OSMS writes in that language.
  String _initialLanguage(OnboardingOptions options) {
    final system = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return options.languages.any((l) => l.code == system) ? system : 'en';
  }

  Future<void> _done(OnboardingPicks picks) async {
    setState(() => _saving = true);
    try {
      await _session.completeOnboarding(picks);
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider.select((s) => s.value?.account?.onboarded ?? false), (_, onboarded) {
      if (!_firstSetup || !onboarded || _saving) return;
      context.go('/');
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('You finished setting up on another device.')),
      );
    });
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
