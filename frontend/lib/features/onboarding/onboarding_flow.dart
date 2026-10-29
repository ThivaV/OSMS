import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/kind_icons.dart';
import '../../shared/widgets/source_chip.dart';
import '../sources/interests_editor.dart';

enum OnboardingStep { language, topics, kinds, research, sources }

/// Topics that make the arXiv research step worth showing.
const _researchTopics = {'ai-research', 'science', 'space'};

/// Short steps, every one skippable. The arXiv research step appears only when a
/// research topic is picked. Picks survive going back and forth.
class Onboarding extends StatefulWidget {
  const Onboarding({
    super.key,
    required this.languages,
    required this.topics,
    required this.suggestions,
    this.researchSuggestions = const [],
    this.initialStep = OnboardingStep.language,
    this.initialLanguage = 'en',
    this.initialTopics = const {},
    this.onDone,
  });

  final List<AppLanguage> languages;
  final List<Topic> topics;
  final List<SourceSuggestion> suggestions;

  /// Related terms the interest agent offers in the research step.
  final List<String> researchSuggestions;
  final OnboardingStep initialStep;
  final String initialLanguage;
  final Set<String> initialTopics;

  /// Called with the picks when the reader finishes, or skips the rest.
  final ValueChanged<OnboardingPicks>? onDone;

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  late OnboardingStep _step = widget.initialStep;
  late String _language = widget.initialLanguage;
  late final Set<String> _topics = {...widget.initialTopics};
  final Set<ItemKind> _kinds = {ItemKind.article, ItemKind.paper, ItemKind.episode, ItemKind.video, ItemKind.post};
  final Set<String> _unticked = {};
  InterestDraft? _interest;

  List<OnboardingStep> get _steps => [
    OnboardingStep.language,
    OnboardingStep.topics,
    OnboardingStep.kinds,
    if (_topics.any(_researchTopics.contains)) OnboardingStep.research,
    OnboardingStep.sources,
  ];

  void _finish() {
    final research = _topics.any(_researchTopics.contains);
    widget.onDone?.call(
      OnboardingPicks(
        language: _language,
        topics: {..._topics},
        kinds: {..._kinds},
        sourceIds: {
          for (final s in widget.suggestions)
            if (_topics.contains(s.topicId) && _kinds.contains(s.kind) && !_unticked.contains(s.source.id)) s.source.id,
        },
        interest: research && !(_interest?.isEmpty ?? true) ? _interest : null,
      ),
    );
  }

  void _go(int delta) {
    final steps = _steps;
    final next = steps.indexOf(_step).clamp(0, steps.length - 1) + delta;
    if (next >= steps.length) {
      _finish();
      return;
    }
    setState(() => _step = steps[next.clamp(0, steps.length - 1)]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final (title, subtitle) = switch (_step) {
      OnboardingStep.language => (
        'Which language should OSMS write in?',
        'Summaries, what’s new and your briefing. Sources can be in any language.',
      ),
      OnboardingStep.topics => ('What do you want to follow?', 'Pick a few. You can change these any time.'),
      OnboardingStep.kinds => (
        'Which kinds of sources?',
        'We suggest these first. Photos and comics appear in your timeline but don’t join stories.',
      ),
      OnboardingStep.research => (
        'Follow research on arXiv?',
        'Add keywords from your field and OSMS pulls new papers about them every morning. '
            'Skip this if you don’t read papers.',
      ),
      OnboardingStep.sources => ('Here’s a starting set', 'All ticked. Untick anything you don’t want.'),
    };
    final steps = _steps;
    final index = steps.indexOf(_step).clamp(0, steps.length - 1);
    final last = _step == OnboardingStep.sources;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Sizes.readingWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Progress(index: index, total: steps.length, onSkip: widget.onDone == null ? null : _finish),
          const SizedBox(height: Space.xl),
          Text(title, style: t.title),
          const SizedBox(height: Space.sm),
          Text(subtitle, style: t.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.xl),
          switch (_step) {
            OnboardingStep.language => _LanguageStep(
              languages: widget.languages,
              selected: _language,
              onSelect: (code) => setState(() => _language = code),
            ),
            OnboardingStep.topics => _TopicStep(
              topics: widget.topics,
              selected: _topics,
              onToggle: (id) => setState(() => _topics.contains(id) ? _topics.remove(id) : _topics.add(id)),
            ),
            OnboardingStep.kinds => _KindStep(
              selected: _kinds,
              onToggle: (k) => setState(() => _kinds.contains(k) ? _kinds.remove(k) : _kinds.add(k)),
            ),
            OnboardingStep.research => InterestsEditor(
              embedded: true,
              suggestedTerms: widget.researchSuggestions,
              initialKeywords: _interest?.keywords ?? const [],
              initialRelated: {...?_interest?.relatedTerms},
              initialCategories: {...?_interest?.categories},
              onChanged: (draft) => _interest = draft,
            ),
            OnboardingStep.sources => _SourceStep(
              topics: widget.topics.where((topic) => _topics.contains(topic.id)).toList(),
              suggestions: widget.suggestions.where((s) => _topics.contains(s.topicId) && _kinds.contains(s.kind)).toList(),
              unticked: _unticked,
              onChanged: () => setState(() {}),
            ),
          },
          const SizedBox(height: Space.xl),
          Row(
            children: [
              if (index > 0) OutlinedButton(onPressed: () => _go(-1), child: const Text('Back')),
              const Spacer(),
              FilledButton(onPressed: () => _go(1), child: Text(last ? 'Start reading' : 'Continue')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.index, required this.total, this.onSkip});

  final int index;
  final int total;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Step ${index + 1} of $total', style: context.text.caption.copyWith(color: c.textTertiary)),
            const Spacer(),
            TextButton(onPressed: onSkip ?? () {}, child: const Text('Skip')),
          ],
        ),
        const SizedBox(height: Space.xs),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              Expanded(
                child: Container(
                  height: Sizes.rail,
                  decoration: BoxDecoration(
                    color: i <= index ? c.accent : c.border,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
              if (i < total - 1) const SizedBox(width: Space.xs),
            ],
          ],
        ),
      ],
    );
  }
}

/// A selectable tile. Selection shows as a check and a heavier border.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.icon,
    this.radio = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      side: BorderSide(
        color: selected ? c.accent : c.border,
        width: selected ? Sizes.focusRing : Sizes.hairline,
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.accentSoft : c.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: Sizes.iconLg, color: c.textSecondary),
                  const SizedBox(width: Space.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.subhead),
                      if (subtitle != null) ...[
                        const SizedBox(height: Space.xxs),
                        Text(subtitle!, style: t.caption.copyWith(color: c.textSecondary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                Icon(
                  selected
                      ? (radio ? Icons.radio_button_checked_rounded : Icons.check_circle_rounded)
                      : (radio ? Icons.radio_button_unchecked_rounded : Icons.circle_outlined),
                  color: selected ? c.accent : c.borderStrong,
                  size: Sizes.iconLg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two columns when there is room, one on phones.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= Sizes.twoColumnMin ? 2 : 1;
        final width = (constraints.maxWidth - Space.md * (columns - 1)) / columns;
        return Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({required this.languages, required this.selected, required this.onSelect});

  final List<AppLanguage> languages;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final lang in languages) ...[
          _ChoiceTile(
            radio: true,
            selected: lang.code == selected,
            onTap: () => onSelect(lang.code),
            title: lang.nativeName,
            subtitle: lang.nativeName == lang.englishName ? null : lang.englishName,
          ),
          if (lang != languages.last) const SizedBox(height: Space.sm),
        ],
      ],
    );
  }
}

IconData _topicIcon(String id) => switch (id) {
  'ai-research' => Icons.hub_outlined,
  'developer-tools' => Icons.terminal_rounded,
  'science' => Icons.science_outlined,
  'space' => Icons.rocket_launch_outlined,
  'startups' => Icons.trending_up_rounded,
  _ => Icons.tag_rounded,
};

class _TopicStep extends StatelessWidget {
  const _TopicStep({required this.topics, required this.selected, required this.onToggle});

  final List<Topic> topics;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _TileGrid(
      children: [
        for (final topic in topics)
          _ChoiceTile(
            icon: _topicIcon(topic.id),
            selected: selected.contains(topic.id),
            onTap: () => onToggle(topic.id),
            title: topic.name,
            subtitle: topic.description,
          ),
      ],
    );
  }
}

class _KindStep extends StatelessWidget {
  const _KindStep({required this.selected, required this.onToggle});

  final Set<ItemKind> selected;
  final ValueChanged<ItemKind> onToggle;

  static const _names = {
    ItemKind.article: ('Articles', 'Blogs, news sites, newsletters'),
    ItemKind.paper: ('Research papers', 'From arXiv, matched to your keywords'),
    ItemKind.episode: ('Podcasts', 'Transcribed, so they join stories'),
    ItemKind.video: ('Videos', 'Channels and playlists'),
    ItemKind.post: ('Social posts', 'Mastodon, Bluesky, Reddit and more'),
    ItemKind.photo: ('Photos', 'In your timeline, not in stories'),
    ItemKind.comic: ('Comics', 'In your timeline, not in stories'),
  };

  @override
  Widget build(BuildContext context) {
    return _TileGrid(
      children: [
        for (final kind in ItemKind.values)
          _ChoiceTile(
            icon: iconForKind(kind),
            selected: selected.contains(kind),
            onTap: () => onToggle(kind),
            title: _names[kind]!.$1,
            subtitle: _names[kind]!.$2,
          ),
      ],
    );
  }
}

class _SourceStep extends StatelessWidget {
  const _SourceStep({required this.topics, required this.suggestions, required this.unticked, required this.onChanged});

  final List<Topic> topics;
  final List<SourceSuggestion> suggestions;

  /// Mutated in place; [onChanged] rebuilds.
  final Set<String> unticked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    if (suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border),
        ),
        child: Text(
          'No suggestions for these picks yet. Finish, then add your own sources with a link, a handle or an OPML file.',
          style: t.body.copyWith(color: c.textSecondary),
        ),
      );
    }

    final ticked = suggestions.where((s) => !unticked.contains(s.source.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${plural(ticked, 'source')} ticked', style: t.caption.copyWith(color: c.textTertiary)),
        for (final topic in topics) ...[
          if (suggestions.any((s) => s.topicId == topic.id))
            _TopicGroup(
              topic: topic,
              suggestions: suggestions.where((s) => s.topicId == topic.id).toList(),
              unticked: unticked,
              onChanged: onChanged,
            ),
        ],
      ],
    );
  }
}

class _TopicGroup extends StatelessWidget {
  const _TopicGroup({required this.topic, required this.suggestions, required this.unticked, required this.onChanged});

  final Topic topic;
  final List<SourceSuggestion> suggestions;
  final Set<String> unticked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final ids = suggestions.map((s) => s.source.id).toSet();
    final allTicked = ids.every((id) => !unticked.contains(id));
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_topicIcon(topic.id), size: Sizes.iconMd, color: c.textSecondary),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(topic.name, style: t.subhead)),
              TextButton(
                onPressed: () {
                  allTicked ? unticked.addAll(ids) : unticked.removeAll(ids);
                  onChanged();
                },
                child: Text(allTicked ? 'Untick all' : 'Tick all'),
              ),
            ],
          ),
          for (final s in suggestions)
            InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () {
                unticked.contains(s.source.id) ? unticked.remove(s.source.id) : unticked.add(s.source.id);
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xxs),
                child: Row(
                  children: [
                    Checkbox(
                      value: !unticked.contains(s.source.id),
                      onChanged: (_) {
                        unticked.contains(s.source.id) ? unticked.remove(s.source.id) : unticked.add(s.source.id);
                        onChanged();
                      },
                    ),
                    SourceAvatar(source: s.source, size: Sizes.avatarMd),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body),
                          Text(
                            [s.source.type.label, languageLabel(s.source.language), if (s.note != null) s.note!]
                                .join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(color: c.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Icon(iconForSourceType(s.source.type), size: Sizes.iconSm, color: c.textTertiary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
