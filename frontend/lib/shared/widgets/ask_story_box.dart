import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import 'citation_chip.dart';
import 'section_header.dart';

/// "Ask this story", below the story's own sections (secondary, rule 4).
/// A typed question, answered only from the story's verified claims — or
/// "Not reported yet". Five states: idle, thinking, answered, not reported,
/// unavailable. The parent owns the async work: [onAsk] fires, then the
/// parent rebuilds with [thinking], [result] or [unavailable].
class AskStoryBox extends StatefulWidget {
  const AskStoryBox({
    super.key,
    this.question,
    this.result,
    this.thinking = false,
    this.unavailable = false,
    this.suggestions = const [],
    this.onAsk,
  });

  /// The last question asked, echoed above its answer.
  final String? question;

  /// The answer, when one arrived. `reported: false` is "Not reported yet".
  final AskResult? result;
  final bool thinking;

  /// The answer service failed. Retry re-asks [question].
  final bool unavailable;

  /// Story-derived prompts ("What do sources disagree on?"), shown when idle.
  final List<String> suggestions;

  /// Null disables asking (e.g. no answer service yet) with the reason below.
  final ValueChanged<String>? onAsk;

  /// Questions are one typed sentence, never stored or logged.
  static const maxQuestionLength = 280;

  @override
  State<AskStoryBox> createState() => _AskStoryBoxState();
}

class _AskStoryBoxState extends State<AskStoryBox> {
  late final _controller = TextEditingController();
  bool _touched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask([String? suggestion]) {
    final ask = widget.onAsk;
    if (ask == null || widget.thinking) return;
    final question = (suggestion ?? _controller.text).trim();
    if (question.isEmpty) {
      setState(() => _touched = true);
      return;
    }
    ask(question);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    // While thinking, or while a failed answer leaves nothing else on screen,
    // the retry inside the panel is the only action.
    final busy = widget.thinking || (widget.unavailable && result == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(icon: Icons.contact_support_outlined, title: 'Ask this story'),
        const SizedBox(height: Space.md),
        if (widget.unavailable && !widget.thinking)
          _Unavailable(question: widget.question, onRetry: () => _ask(widget.question))
        else if (widget.thinking)
          const _Thinking()
        else if (result != null && result.reported)
          _Answered(result: result)
        else if (result != null)
          _NotReported(result: result),
        if (!busy) ...[
          const SizedBox(height: Space.md),
          _QuestionField(
            controller: _controller,
            enabled: widget.onAsk != null,
            showError: _touched && _controller.text.trim().isEmpty,
            onChanged: (_) => _touched ? setState(() {}) : null,
            onAsk: () => _ask(),
          ),
        ],
        if (widget.onAsk == null) ...[
          const SizedBox(height: Space.xs),
          Text(
            'Answers arrive with real stories; the demo only shows the shape.',
            style: context.text.caption.copyWith(color: context.colors.textTertiary),
          ),
        ] else if (widget.question == null && result == null && widget.suggestions.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          _Suggestions(suggestions: widget.suggestions, onPick: _ask),
        ],
      ],
    );
  }
}

class _QuestionField extends StatelessWidget {
  const _QuestionField({
    required this.controller,
    required this.enabled,
    required this.showError,
    required this.onChanged,
    required this.onAsk,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool showError;
  final ValueChanged<String> onChanged;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                maxLength: AskStoryBox.maxQuestionLength,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onChanged: onChanged,
                onSubmitted: (_) => onAsk(),
                style: t.body,
                decoration: const InputDecoration(
                  hintText: 'Ask about this story',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            FilledButton.icon(
              onPressed: enabled ? onAsk : null,
              icon: const Icon(Icons.send_rounded, size: Sizes.iconMd),
              label: const Text('Ask'),
            ),
          ],
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text('Type a question first.', style: t.caption.copyWith(color: c.error)),
          ),
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final s in suggestions)
          OutlinedButton(
            onPressed: () => onPick(s),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            ),
            child: Text(s, style: context.text.label),
          ),
      ],
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: Sizes.iconMd, height: Sizes.iconMd, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              'Checking this story\u2019s verified facts\u2026',
              style: t.bodySmall.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Answered extends StatelessWidget {
  const _Answered({required this.result});

  final AskResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.question, style: t.subhead),
          const SizedBox(height: Space.md),
          for (final segment in result.segments) ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${segment.text} '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: CitationGroup(sources: segment.sources),
                  ),
                ],
              ),
              style: t.reading,
            ),
            if (segment != result.segments.last) const SizedBox(height: Space.md),
          ],
          const SizedBox(height: Space.md),
          Text(
            'Answered only from this story\u2019s verified facts. Nothing was stored.',
            style: t.caption.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _NotReported extends StatelessWidget {
  const _NotReported({required this.result});

  final AskResult result;

  @override
  Widget build(BuildContext context) {
    return QuietNote(
      icon: Icons.help_outline_rounded,
      title: 'Not reported yet',
      body:
          'None of this story\u2019s verified facts answer \u201C${result.question}\u201D. '
          'OSMS answers only from what its sources reported.',
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.question, required this.onRetry});

  final String? question;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return QuietNote(
      icon: Icons.cloud_off_outlined,
      title: 'Couldn\u2019t reach the answer service',
      body: 'Your question went nowhere and nothing was stored. Try again.',
      action: question == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: Sizes.iconMd),
              label: const Text('Ask again'),
            ),
    );
  }
}
