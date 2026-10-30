import 'package:flutter/material.dart';

import '../../shared/widgets/story_card.dart';
import '../models/models.dart';
import '../session/account.dart';
import '../theme/appearance.dart';

/// JSON to and from the OSMS API (snake_case on the wire). Models stay plain.
typedef Json = Map<String, Object?>;

List<Json> _list(Object? value) => [for (final item in (value as List<Object?>? ?? const [])) item as Json];
List<String> _strings(Object? value) => [for (final item in (value as List<Object?>? ?? const [])) item as String];

T? _byName<T extends Enum>(List<T> values, Object? name) => values.where((v) => v.name == name).firstOrNull;

Topic topicFromJson(Json j) =>
    Topic(id: j['id'] as String, name: j['name'] as String, description: (j['description'] as String?) ?? '');

Source sourceFromJson(Json j, {bool followed = false}) => Source(
  id: j['id'] as String,
  name: j['name'] as String,
  type: _byName(SourceType.values, j['type']) ?? SourceType.feed,
  language: (j['language'] as String?) ?? 'en',
  url: j['url'] as String?,
  followed: followed,
);

ResearchInterest interestFromJson(Json j) => ResearchInterest(
  id: j['id'] as String,
  keywords: _strings(j['keywords']),
  relatedTerms: _strings(j['related_terms']),
  categories: _strings(j['categories']),
);

Json interestToJson(InterestDraft draft) => {
  'keywords': draft.keywords,
  'related_terms': draft.relatedTerms,
  'categories': draft.categories,
};

Appearance appearanceFromJson(Json j) => Appearance(
  mode: _byName(ThemeMode.values, j['mode']) ?? ThemeMode.system,
  paletteId: (j['palette_id'] as String?) ?? 'folio',
  pureBlack: j['pure_black'] == true,
  readingFont: _byName(ReadingFont.values, j['reading_font']) ?? ReadingFont.serif,
  readingScale: ((j['reading_scale'] as num?) ?? 1).toDouble(),
  glass: _byName(GlassStyle.values, j['glass']) ?? GlassStyle.frosted,
);

Json appearanceToJson(Appearance a) => {
  'mode': a.mode.name,
  'palette_id': a.paletteId,
  'pure_black': a.pureBlack,
  'reading_font': a.readingFont.name,
  'reading_scale': a.readingScale,
  'glass': a.glass.name,
};

Account accountFromJson(Json j) => Account(
  user: User(
    id: j['id'] as String,
    displayName: (j['display_name'] as String?) ?? '',
    email: j['email'] as String,
    language: (j['language'] as String?) ?? 'en',
  ),
  topics: _list(j['topics']).map(topicFromJson).toList(),
  kinds: {for (final k in _strings(j['kinds'])) ?_byName(ItemKind.values, k)},
  subscriptions: [for (final s in _list(j['subscriptions'])) sourceFromJson(s, followed: true)],
  interests: _list(j['interests']).map(interestFromJson).toList(),
  appearance: j['appearance'] is Json ? appearanceFromJson(j['appearance'] as Json) : null,
  defaultLayout: _byName(StoryCardLayout.values, j['default_layout']),
  onboarded: j['onboarded'] == true,
);

OnboardingOptions onboardingOptionsFromJson(Json j) => OnboardingOptions(
  languages: [
    for (final l in _list(j['languages']))
      AppLanguage(
        code: l['code'] as String,
        nativeName: l['native_name'] as String,
        englishName: l['english_name'] as String,
      ),
  ],
  topics: _list(j['topics']).map(topicFromJson).toList(),
  suggestions: [
    for (final s in _list(j['suggestions']))
      SourceSuggestion(
        source: sourceFromJson(s['source'] as Json),
        topicId: s['topic_id'] as String,
        kind: _byName(ItemKind.values, s['kind']) ?? ItemKind.article,
        note: s['note'] as String?,
      ),
  ],
);

Json onboardingToJson(OnboardingPicks picks) => {
  'language': picks.language,
  'topics': [...picks.topics],
  'kinds': [for (final k in picks.kinds) k.name],
  'source_ids': [...picks.sourceIds],
  'interests': [if (picks.interest case final interest?) interestToJson(interest)],
};

// ── Stories ─────────────────────────────────────────────────────────────────

DateTime _time(Object? value) => DateTime.parse(value as String).toLocal();

Source storySourceFromJson(Json j) => sourceFromJson(j, followed: j['followed'] == true);

List<Source> _sources(Object? value) => _list(value).map(storySourceFromJson).toList();

Claim claimFromJson(Json j) => Claim(
  id: j['id'] as String,
  text: j['text'] as String,
  sources: _sources(j['sources']),
  reportedAt: _time(j['reported_at']),
  quote: j['quote'] as String?,
  quoteLanguage: j['quote_language'] as String?,
  translation: j['translation'] as String?,
  corrects: j['corrects'] as String?,
);

Disagreement disagreementFromJson(Json j) => Disagreement(
  id: j['id'] as String,
  topic: j['topic'] as String,
  sides: [
    for (final s in _list(j['sides']))
      DisagreementSide(value: s['value'] as String, claim: s['claim'] as String, sources: _sources(s['sources'])),
  ],
);

TimelineEvent timelineEventFromJson(Json j) => TimelineEvent(
  id: j['id'] as String,
  at: _time(j['at']),
  text: j['text'] as String,
  kind: _byName(ItemKind.values, j['kind']) ?? ItemKind.article,
  sourceCount: (j['source_count'] as num?)?.toInt() ?? 1,
  url: j['url'] as String?,
  correctedFrom: j['corrected_from'] as String?,
);

Story storyFromJson(Json j) => Story(
  id: j['id'] as String,
  title: j['title'] as String,
  summary: (j['summary'] as String?) ?? '',
  summaryPoints: [
    for (final p in _list(j['summary_points']))
      SummaryPoint(text: p['text'] as String, sources: _sources(p['sources'])),
  ],
  topic: (j['topic'] as String?) ?? 'News',
  updatedAt: _time(j['updated_at']),
  sources: _sources(j['sources']),
  kindCounts: {
    for (final entry in ((j['kind_counts'] as Map<String, Object?>?) ?? const {}).entries)
      ?_byName(ItemKind.values, entry.key): (entry.value as num).toInt(),
  },
  languages: _strings(j['languages']),
  visualSeed: (j['visual_seed'] as num?)?.toInt() ?? 0,
  hasIllustration: j['has_illustration'] == true,
  lastReadAt: j['last_read_at'] == null ? null : _time(j['last_read_at']),
  whatsNew: _list(j['whats_new']).map(claimFromJson).toList(),
  disagreements: _list(j['disagreements']).map(disagreementFromJson).toList(),
  timeline: _list(j['timeline']).map(timelineEventFromJson).toList(),
  why: _strings(j['why']),
);

List<Story> storiesFromJson(Json j) => _list(j['stories']).map(storyFromJson).toList();
