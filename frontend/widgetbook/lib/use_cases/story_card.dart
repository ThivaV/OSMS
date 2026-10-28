import 'package:flutter/material.dart';
import 'package:osms/core/theme/tokens.dart';
import 'package:osms/shared/widgets/story_card.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;
import 'frame.dart';

StoryCardLayout _layout(BuildContext context) => context.knobs.object.segmented(
  label: 'Layout',
  options: StoryCardLayout.values,
  labelBuilder: (l) => l.name,
);

@widgetbook.UseCase(name: 'Normal', type: StoryCard, path: '[Story]')
Widget storyCardNormal(BuildContext context) {
  final title = context.knobs.string(label: 'Title', initialValue: fx.halcyon.title);
  return Frame(
    child: StoryCard(
      story: fx.halcyon.copyWith(title: title),
      layout: _layout(context),
      selected: context.knobs.boolean(label: 'Selected'),
      onTap: () {},
    ),
  );
}

@widgetbook.UseCase(name: 'Every story', type: StoryCard, path: '[Story]')
Widget storyCardAll(BuildContext context) {
  final layout = _layout(context);
  return Frame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final story in fx.stories) ...[
          StoryCard(story: story, layout: layout, onTap: () {}),
          const SizedBox(height: Space.lg),
        ],
      ],
    ),
  );
}

@widgetbook.UseCase(name: 'Empty', type: StoryCard, path: '[Story]')
Widget storyCardEmpty(BuildContext context) {
  return Frame(
    child: Variants(
      children: {
        'Never read, two sources': StoryCard(story: fx.selene, layout: _layout(context), onTap: () {}),
        'Read, nothing new since': StoryCard(story: fx.microbes, layout: _layout(context), onTap: () {}),
      },
    ),
  );
}

@widgetbook.UseCase(name: 'Extreme content', type: StoryCard, path: '[Story]')
Widget storyCardExtreme(BuildContext context) {
  return Frame(child: StoryCard(story: fx.extremeStory, layout: _layout(context), onTap: () {}));
}
