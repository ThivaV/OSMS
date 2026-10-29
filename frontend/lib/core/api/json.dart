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
      AppLanguage(code: l['code'] as String, nativeName: l['native_name'] as String, englishName: l['english_name'] as String),
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
