import 'package:flutter/painting.dart' show Alignment;

import 'item.dart';
import 'source.dart';

/// One sentence of our summary, with the sources it rests on.
class SummaryPoint {
  const SummaryPoint({required this.text, required this.sources});

  final String text;
  final List<Source> sources;
}

/// A fact one or more sources reported.
class Claim {
  const Claim({
    required this.id,
    required this.text,
    required this.sources,
    required this.reportedAt,
    this.quote,
    this.quoteLanguage,
    this.translation,
    this.corrects,
  });

  final String id;
  final String text;
  final List<Source> sources;
  final DateTime reportedAt;

  /// The words it rests on, exactly as the source wrote them, in [quoteLanguage].
  final String? quote;
  final String? quoteLanguage;

  /// [quote] in English when the source wrote in another language: "Translated by OSMS".
  final String? translation;

  /// For a correction: what the source said before.
  final String? corrects;

  /// Only one source reports it so far.
  bool get singleSource => sources.length == 1;
}

/// One side of a disagreement: a value, the claim behind it, who said it.
class DisagreementSide {
  const DisagreementSide({required this.value, required this.claim, required this.sources});

  /// The contested fact in short form, e.g. "1.2 trillion" or "14:02 UTC".
  final String value;
  final String claim;
  final List<Source> sources;
}

class Disagreement {
  const Disagreement({required this.id, required this.topic, required this.sides});

  final String id;

  /// What the sources disagree about, e.g. "Parameter count".
  final String topic;
  final List<DisagreementSide> sides;
}

class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.at,
    required this.text,
    required this.kind,
    required this.sourceCount,
    this.url,
    this.correctedFrom,
  });

  final String id;
  final DateTime at;
  final String text;

  /// The kind of item that first reported it.
  final ItemKind kind;
  final int sourceCount;

  /// The original article, on its publisher's site.
  final String? url;

  /// For a correction: the value the source replaced, shown struck through.
  final String? correctedFrom;
}

class Story {
  const Story({
    required this.id,
    required this.title,
    required this.summary,
    required this.topic,
    required this.updatedAt,
    required this.sources,
    required this.kindCounts,
    required this.languages,
    required this.visualSeed,
    this.hasIllustration = false,
    this.illustrationUrl,
    this.illustrationFocus = Alignment.center,
    this.lastReadAt,
    this.summaryPoints = const [],
    this.whatsNew = const [],
    this.disagreements = const [],
    this.timeline = const [],
    this.why = const [],
  });

  final String id;
  final String title;

  /// Our own summary, in the reader's language.
  final String summary;

  /// The same summary, sentence by sentence, each with its sources. The story
  /// page cites these; cards use [summary].
  final List<SummaryPoint> summaryPoints;
  final String topic;
  final DateTime updatedAt;
  final List<Source> sources;

  /// How many items of each kind fed the story.
  final Map<ItemKind, int> kindCounts;
  final List<String> languages;

  /// Seeds the placeholder visual until Muse Image provides one.
  final int visualSeed;

  /// True once Muse Image has provided an illustration (SAM 3.1 checked).
  /// Shows the mandated "Illustration" label over the art.
  final bool hasIllustration;

  /// The checked illustration itself; null until there is one (the drawn art stays).
  final String? illustrationUrl;

  /// Where its subject is, so every card shape crops around it.
  final Alignment illustrationFocus;

  /// When the reader last opened it. Null if never.
  final DateTime? lastReadAt;

  /// Claims reported since [lastReadAt].
  final List<Claim> whatsNew;
  final List<Disagreement> disagreements;
  final List<TimelineEvent> timeline;

  /// Why it is in the reader's list, in words: "3 sources", "2 new facts", "AI research".
  final List<String> why;

  int get newFactCount => whatsNew.length;
  int get itemCount => kindCounts.values.fold(0, (sum, n) => sum + n);

  Story copyWith({String? title, List<Claim>? whatsNew, DateTime? lastReadAt, bool? hasIllustration}) => Story(
    id: id,
    title: title ?? this.title,
    summary: summary,
    topic: topic,
    updatedAt: updatedAt,
    sources: sources,
    kindCounts: kindCounts,
    languages: languages,
    visualSeed: visualSeed,
    hasIllustration: hasIllustration ?? this.hasIllustration,
    illustrationUrl: illustrationUrl,
    illustrationFocus: illustrationFocus,
    lastReadAt: lastReadAt ?? this.lastReadAt,
    summaryPoints: summaryPoints,
    whatsNew: whatsNew ?? this.whatsNew,
    disagreements: disagreements,
    timeline: timeline,
    why: why,
  );
}
