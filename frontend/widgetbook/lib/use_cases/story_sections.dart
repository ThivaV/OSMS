import 'package:flutter/material.dart';
import 'package:osms/core/theme/tokens.dart';
import 'package:osms/features/story_detail/story_detail_view.dart';
import 'package:osms/shared/widgets/disagreement_panel.dart';
import 'package:osms/shared/widgets/story_timeline.dart';
import 'package:osms/shared/widgets/whats_new_section.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;
import 'frame.dart';

const _sectionWidth = Sizes.readingWidth;

// ── What's new ───────────────────────────────────────────────────────────────

@widgetbook.UseCase(name: 'Normal', type: WhatsNewSection, path: '[Story]')
Widget whatsNewNormal(BuildContext context) => Frame(
  maxWidth: _sectionWidth,
  child: WhatsNewSection(claims: fx.halcyon.whatsNew, since: fx.halcyon.lastReadAt, onOpenSource: (_) {}),
);

@widgetbook.UseCase(name: 'Empty', type: WhatsNewSection, path: '[Story]')
Widget whatsNewEmpty(BuildContext context) => Frame(
  maxWidth: _sectionWidth,
  child: WhatsNewSection(claims: const [], since: fx.microbes.lastReadAt),
);

@widgetbook.UseCase(name: 'Extreme content', type: WhatsNewSection, path: '[Story]')
Widget whatsNewExtreme(BuildContext context) => Frame(
  maxWidth: _sectionWidth,
  child: WhatsNewSection(claims: fx.extremeStory.whatsNew, since: fx.extremeStory.lastReadAt, onOpenSource: (_) {}),
);

// ── Where sources disagree ───────────────────────────────────────────────────

@widgetbook.UseCase(name: 'Normal', type: DisagreementPanel, path: '[Story]')
Widget disagreementNormal(BuildContext context) => Frame(
  maxWidth: _sectionWidth,
  child: DisagreementPanel(disagreements: fx.halcyon.disagreements, onOpenSource: (_) {}),
);

@widgetbook.UseCase(name: 'Empty', type: DisagreementPanel, path: '[Story]')
Widget disagreementEmpty(BuildContext context) =>
    const Frame(maxWidth: _sectionWidth, child: DisagreementPanel(disagreements: []));

@widgetbook.UseCase(name: 'Extreme content', type: DisagreementPanel, path: '[Story]')
Widget disagreementExtreme(BuildContext context) => Frame(
  maxWidth: _sectionWidth,
  child: DisagreementPanel(disagreements: fx.extremeStory.disagreements, onOpenSource: (_) {}),
);

// ── Timeline ─────────────────────────────────────────────────────────────────

@widgetbook.UseCase(name: 'Normal', type: StoryTimeline, path: '[Story]')
Widget timelineNormal(BuildContext context) => Frame(
  maxWidth: _sectionWidth,
  child: StoryTimeline(events: fx.halcyon.timeline, lastReadAt: fx.halcyon.lastReadAt),
);

@widgetbook.UseCase(name: 'Empty', type: StoryTimeline, path: '[Story]')
Widget timelineEmpty(BuildContext context) =>
    const Frame(maxWidth: _sectionWidth, child: StoryTimeline(events: []));

@widgetbook.UseCase(name: 'Extreme content', type: StoryTimeline, path: '[Story]')
Widget timelineExtreme(BuildContext context) => Frame(
  maxWidth: _sectionWidth,
  child: StoryTimeline(events: fx.extremeStory.timeline, lastReadAt: fx.extremeStory.lastReadAt),
);

// ── The whole story page ─────────────────────────────────────────────────────

@widgetbook.UseCase(name: 'Normal', type: StoryDetailView, path: '[Story]')
Widget storyPageNormal(BuildContext context) => Material(child: StoryDetailView(story: fx.halcyon));

@widgetbook.UseCase(name: 'Empty', type: StoryDetailView, path: '[Story]')
Widget storyPageEmpty(BuildContext context) => Material(child: StoryDetailView(story: fx.selene));

@widgetbook.UseCase(name: 'Extreme content', type: StoryDetailView, path: '[Story]')
Widget storyPageExtreme(BuildContext context) => Material(child: StoryDetailView(story: fx.extremeStory));
