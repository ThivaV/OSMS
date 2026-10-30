import 'package:flutter/material.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/core/theme/tokens.dart';
import 'package:osms/features/story_detail/story_detail_view.dart';
import 'package:osms/shared/widgets/ask_story_box.dart';
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

// ── Ask this story ───────────────────────────────────────────────────────────
// A state machine, so one use case per state rather than the usual trilogy.

@widgetbook.UseCase(name: 'Answered', type: AskStoryBox, path: '[Story]')
Widget askAnswered(BuildContext context) => Frame(
  maxWidth: _sectionWidth,
  child: AskStoryBox(
    question: fx.halcyonAskAnswered.question,
    result: fx.halcyonAskAnswered,
    suggestions: fx.halcyonAskSuggestions,
    onAsk: (_) {},
  ),
);

@widgetbook.UseCase(name: 'Idle', type: AskStoryBox, path: '[Story]')
Widget askIdle(BuildContext context) => Frame(
  maxWidth: _sectionWidth,
  child: AskStoryBox(suggestions: fx.halcyonAskSuggestions, onAsk: (_) {}),
);

@widgetbook.UseCase(name: 'Thinking', type: AskStoryBox, path: '[Story]')
Widget askThinking(BuildContext context) => const Frame(
  maxWidth: _sectionWidth,
  child: AskStoryBox(question: 'How big is the model?', thinking: true, onAsk: _noopAsk),
);

void _noopAsk(String _) {}

@widgetbook.UseCase(name: 'Not reported', type: AskStoryBox, path: '[Story]')
Widget askNotReported(BuildContext context) => Frame(
  maxWidth: _sectionWidth,
  child: AskStoryBox(
    question: fx.halcyonAskNotReported.question,
    result: fx.halcyonAskNotReported,
    suggestions: fx.halcyonAskSuggestions,
    onAsk: (_) {},
  ),
);

@widgetbook.UseCase(name: 'Unavailable', type: AskStoryBox, path: '[Story]')
Widget askUnavailable(BuildContext context) => const Frame(
  maxWidth: _sectionWidth,
  child: AskStoryBox(question: 'How big is the model?', unavailable: true, onAsk: _noopAsk),
);

@widgetbook.UseCase(name: 'Live', type: AskStoryBox, path: '[Story]')
Widget askLive(BuildContext context) => const Frame(maxWidth: _sectionWidth, child: _LiveAsk());

/// Asks, thinks for a moment, then answers from the fake facts — or reports
/// nothing when the question names nothing the story covers.
class _LiveAsk extends StatefulWidget {
  const _LiveAsk();

  @override
  State<_LiveAsk> createState() => _LiveAskState();
}

class _LiveAskState extends State<_LiveAsk> {
  String? _question;
  AskResult? _result;
  bool _thinking = false;

  void _ask(String question) {
    setState(() {
      _question = question;
      _result = null;
      _thinking = true;
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _result = question.toLowerCase().contains('cost')
            ? const AskResult(question: 'What does it cost?', segments: [], reported: false)
            : AskResult(question: question, segments: fx.halcyonAskAnswered.segments, reported: true);
      });
    });
  }

  @override
  Widget build(BuildContext context) => AskStoryBox(
    question: _question,
    result: _result,
    thinking: _thinking,
    suggestions: fx.halcyonAskSuggestions,
    onAsk: _ask,
  );
}

// ── The whole story page ─────────────────────────────────────────────────────

@widgetbook.UseCase(name: 'Normal', type: StoryDetailView, path: '[Story]')
Widget storyPageNormal(BuildContext context) => Material(child: StoryDetailView(story: fx.halcyon));

@widgetbook.UseCase(name: 'Empty', type: StoryDetailView, path: '[Story]')
Widget storyPageEmpty(BuildContext context) => Material(child: StoryDetailView(story: fx.selene));

@widgetbook.UseCase(name: 'Extreme content', type: StoryDetailView, path: '[Story]')
Widget storyPageExtreme(BuildContext context) => Material(child: StoryDetailView(story: fx.extremeStory));
