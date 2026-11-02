// How the sidebar files sources into topic folders.

import 'package:flutter_test/flutter_test.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/features/sources/source_groups.dart';

const ai = Topic(id: 'ai', name: 'AI research', description: '');
const science = Topic(id: 'science', name: 'Science', description: '');
const space = Topic(id: 'space', name: 'Space', description: '');

Source source(String id, String name) => Source(id: id, name: name, type: SourceType.feed, language: 'en');

SourceSuggestion suggest(Source s, Topic t) => SourceSuggestion(source: s, topicId: t.id, kind: ItemKind.article);

void main() {
  final verge = source('1', 'The Verge: AI');
  final arxiv = source('2', 'arXiv cs.AI');
  final nature = source('3', 'Nature News');
  final blog = source('4', 'a blog nobody suggested');
  final suggestions = [suggest(verge, ai), suggest(arxiv, ai), suggest(arxiv, science), suggest(nature, science)];

  test('each source sits in one folder: a followed topic first, then onboarding order; names sorted', () {
    final groups = groupSources(
      sources: [verge, arxiv, nature, blog],
      followed: [science],
      allTopics: [ai, science, space],
      suggestions: suggestions,
    );
    expect([for (final g in groups) g.name], ['Science', 'AI research', 'Other sources']);
    expect([for (final s in groups[0].sources) s.name], ['arXiv cs.AI', 'Nature News'], reason: 'in both; Science is followed');
    expect([for (final s in groups[1].sources) s.name], ['The Verge: AI']);
    expect(groups[2].sources, [blog]);
    expect(groups.any((g) => g.topic == space), isFalse, reason: 'not followed and nothing in it: no folder');
  });

  test('a followed topic keeps its folder when empty; without topics every source is other', () {
    final groups = groupSources(sources: [verge], followed: [space], allTopics: [ai, space], suggestions: suggestions);
    expect([for (final g in groups) (g.name, g.sources.length)], [('Space', 0), ('AI research', 1)]);
    expect([for (final g in groupSources(sources: [verge, blog], followed: const [])) g.id], [SourceGroup.otherId]);
  });
}
