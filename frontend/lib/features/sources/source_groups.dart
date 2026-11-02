import '../../core/models/models.dart';

/// A folder in the sidebar: a topic and the sources filed under it, or, without a topic,
/// the sources no topic suggests.
class SourceGroup {
  const SourceGroup({required this.sources, this.topic});

  /// Null for "Other sources".
  final Topic? topic;
  final List<Source> sources;

  String get id => topic?.id ?? otherId;
  String get name => topic?.name ?? 'Other sources';

  static const otherId = 'other-sources';
}

/// Files each source in one topic's folder, the way a story gets its topic from its
/// sources: a topic the reader follows first, then the first topic, in onboarding order,
/// that suggests the source. Followed topics keep their folder even when empty; sources
/// no topic suggests go last, under "Other sources". Names sort alphabetically.
List<SourceGroup> groupSources({
  required List<Source> sources,
  required List<Topic> followed,
  List<Topic> allTopics = const [],
  List<SourceSuggestion> suggestions = const [],
}) {
  final order = [...followed, ...allTopics.where((t) => !followed.any((f) => f.id == t.id))];
  final suggestedIn = <String, Set<String>>{};
  for (final s in suggestions) {
    (suggestedIn[s.source.id] ??= {}).add(s.topicId);
  }
  final filed = {for (final t in order) t.id: <Source>[]};
  final other = <Source>[];
  for (final source in sources) {
    final topic = order.where((t) => suggestedIn[source.id]?.contains(t.id) ?? false).firstOrNull;
    (topic == null ? other : filed[topic.id]!).add(source);
  }
  int byName(Source a, Source b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return [
    for (final t in order)
      if (filed[t.id]!.isNotEmpty || followed.any((f) => f.id == t.id))
        SourceGroup(topic: t, sources: filed[t.id]!..sort(byName)),
    if (other.isNotEmpty) SourceGroup(sources: other..sort(byName)),
  ];
}
