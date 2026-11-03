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

/// A source found from a link or handle, with its latest posts: titles and links only.
DiscoveredSource discoveredSourceFromJson(Json j) {
  final source = sourceFromJson(j['source'] as Json, followed: j['already_followed'] == true);
  return DiscoveredSource(
    source: source,
    latest: [
      for (final (i, item) in _list(j['latest']).indexed)
        Item(
          id: '${source.id}-$i',
          source: source,
          kind: _byName(ItemKind.values, item['kind']) ?? ItemKind.article,
          publishedAt: item['published_at'] == null ? DateTime.now() : _time(item['published_at']),
          title: item['title'] as String?,
          url: item['url'] as String?,
        ),
    ],
    frequency: j['frequency'] as String?,
    alreadyFollowed: j['already_followed'] == true,
  );
}

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

Duration _ms(Object? value) => Duration(milliseconds: (value as num).toInt());

Briefing briefingFromJson(Json j) => Briefing(
  id: j['id'] as String,
  date: _time(j['created_at']),
  audioUrl: j['audio_url'] as String,
  total: _ms(j['duration_ms']),
  chapters: [
    for (final c in _list(j['chapters']))
      BriefingChapter(
        storyId: c['story_id'] as String,
        title: c['title'] as String,
        start: _ms(c['start_ms']),
        duration: _ms(c['duration_ms']),
        newFactCount: (c['new_fact_count'] as num?)?.toInt() ?? 0,
        sentences: [
          for (final s in _list(c['sentences']))
            SummaryPoint(text: s['text'] as String, sources: _sources(s['sources'])),
        ],
      ),
  ],
);

/// A paper for the reader's research interests, with the words that brought it.
Item paperFromJson(Json j) => Item(
  id: j['id'] as String,
  source: storySourceFromJson(j['source'] as Json),
  kind: ItemKind.paper,
  publishedAt: _time(j['published_at']),
  title: j['title'] as String,
  text: j['abstract'] as String,
  url: j['url'] as String?,
  hasThumbnail: false,
  paperId: j['paper_id'] as String?,
  version: (j['version'] as num?)?.toInt(),
  matchedTerms: [for (final t in (j['matched_terms'] as List?) ?? const []) t as String],
);

/// An episode of the reader's podcasts, with its show and its story link.
Episode episodeFromJson(Json j) {
  final seconds = (j['duration_s'] as num?)?.toInt();
  return Episode(
    id: j['id'] as String,
    title: j['title'] as String,
    excerpt: (j['excerpt'] as String?) ?? '',
    publishedAt: j['published_at'] == null ? null : _time(j['published_at']),
    duration: seconds == null ? null : Duration(seconds: seconds),
    audioUrl: j['audio_url'] as String?,
    show: sourceFromJson(j['show'] as Json),
    storyId: j['story_id'] as String?,
    storyTitle: j['story_title'] as String?,
  );
}

List<Episode> episodesFromJson(Json j) => [for (final e in _list(j['episodes'])) episodeFromJson(e)];

EpisodesPage episodesPageFromJson(Json j) => EpisodesPage(
  episodes: episodesFromJson(j),
  shows: [for (final s in _list(j['shows'])) sourceFromJson(s)],
  nextCursor: j['next_cursor'] as String?,
);

List<Briefing> briefingsFromJson(Json j) => [for (final b in _list(j['briefings'])) briefingFromJson(b)];

/// A video row: the publisher's page plus the story it joined, when it joined one.
Video videoFromJson(Json j) {
  final seconds = (j['duration_s'] as num?)?.toInt();
  return Video(
    id: j['id'] as String,
    title: j['title'] as String,
    excerpt: (j['excerpt'] as String?) ?? '',
    publishedAt: _time(j['published_at']),
    duration: seconds == null ? null : Duration(seconds: seconds),
    link: j['link'] as String,
    source: storySourceFromJson(j['source'] as Json),
    storyId: j['story_id'] as String?,
    storyTitle: j['story_title'] as String?,
  );
}

List<Video> videosFromJson(Json j) => [for (final v in _list(j['videos'])) videoFromJson(v)];

Decision decisionFromJson(Json j) => Decision(
  id: j['id'] as String,
  agent: j['agent'] as String,
  model: j['model'] as String,
  fallback: j['fallback'] as String?,
  at: _time(j['at']),
  latency: j['latency_ms'] == null ? null : _ms(j['latency_ms']),
  inputTokens: (j['input_tokens'] as num?)?.toInt() ?? 0,
  outputTokens: (j['output_tokens'] as num?)?.toInt() ?? 0,
  about: j['about'] as String?,
  source: j['source'] as String?,
  reason: j['reason'] as String?,
  outcome: j['outcome'] as String?,
);

/// An answer from the story's checked facts: each sentence with the sources behind it.
AskResult askResultFromJson(Json j) => AskResult(
  question: j['question'] as String,
  reported: j['reported'] == true,
  segments: [
    for (final s in _list(j['sentences'])) SummaryPoint(text: s['text'] as String, sources: _sources(s['sources'])),
  ],
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

/// An illustration's address: the API sends it relative to itself.
String? _illustrationUrl(Object? path, Uri? base) =>
    path is String ? (base == null ? path : base.resolve(path).toString()) : null;

/// A source's picture: https only, as the server sends it.
StoryImage? _image(Object? value) {
  if (value is! Map<String, Object?>) return null;
  final url = value['url'];
  if (url is! String || !url.startsWith('https://')) return null;
  return StoryImage(
    url: url,
    source: (value['source'] as String?) ?? '',
    link: value['link'] as String?,
    small: value['small'] == true,
  );
}

Alignment _focus(Object? value) {
  final xy = value is List && value.length == 2 ? value.cast<num>() : null;
  return xy == null ? Alignment.center : Alignment(xy[0] * 2 - 1, xy[1] * 2 - 1);
}

Story storyFromJson(Json j, {Uri? base}) => Story(
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
  illustrationUrl: _illustrationUrl(j['illustration_url'], base),
  illustrationFocus: _focus(j['illustration_focus']),
  image: _image(j['image']),
  lastReadAt: j['last_read_at'] == null ? null : _time(j['last_read_at']),
  whatsNew: _list(j['whats_new']).map(claimFromJson).toList(),
  disagreements: _list(j['disagreements']).map(disagreementFromJson).toList(),
  timeline: _list(j['timeline']).map(timelineEventFromJson).toList(),
  why: _strings(j['why']),
);

List<Story> storiesFromJson(Json j, {Uri? base}) => [for (final s in _list(j['stories'])) storyFromJson(s, base: base)];
