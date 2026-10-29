import 'package:flutter/material.dart';
import 'package:osms/core/theme/tokens.dart';
import 'package:osms/features/onboarding/onboarding_flow.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;
import 'frame.dart';

OnboardingStep _step(BuildContext context) => context.knobs.object.segmented(
  label: 'Start at step',
  options: OnboardingStep.values,
  labelBuilder: (s) => s.name,
);

@widgetbook.UseCase(name: 'Normal', type: Onboarding, path: '[Onboarding]')
Widget onboardingNormal(BuildContext context) {
  final step = _step(context);
  return Frame(
    maxWidth: Sizes.readingWidth,
    child: Onboarding(
      key: ValueKey(step),
      languages: fx.languages,
      topics: fx.topics,
      suggestions: fx.suggestions,
      researchSuggestions: fx.researchSuggestions,
      initialStep: step,
      initialTopics: const {'ai-research', 'space'},
    ),
  );
}

@widgetbook.UseCase(name: 'Empty', type: Onboarding, path: '[Onboarding]')
Widget onboardingEmpty(BuildContext context) => const Frame(
  maxWidth: Sizes.readingWidth,
  child: Onboarding(
    languages: fx.languages,
    topics: fx.topics,
    suggestions: [],
    initialStep: OnboardingStep.sources,
    initialTopics: {'science'},
  ),
);

@widgetbook.UseCase(name: 'Extreme content', type: Onboarding, path: '[Onboarding]')
Widget onboardingExtreme(BuildContext context) {
  final step = _step(context);
  return Frame(
    maxWidth: Sizes.readingWidth,
    child: Onboarding(
      key: ValueKey(step),
      languages: fx.languages,
      topics: [...fx.topics, ...fx.manyTopics],
      suggestions: fx.manySuggestions,
      researchSuggestions: [...fx.researchSuggestions, ...fx.extremeKeywords],
      initialStep: step,
      initialTopics: {'ai-research', for (final t in fx.manyTopics.take(12)) t.id},
    ),
  );
}
