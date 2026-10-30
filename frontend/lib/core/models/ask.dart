import 'story.dart';

/// An answer to one typed question about one story, drawn only from that
/// story's verified claims. Nothing is stored or logged (rule 7).
class AskResult {
  const AskResult({required this.question, required this.segments, required this.reported});

  /// The reader's question, echoed back.
  final String question;

  /// The answer, sentence by sentence, each with its sources. Empty when
  /// [reported] is false. Reuses [SummaryPoint]: one cited sentence each.
  final List<SummaryPoint> segments;

  /// False means "Not reported yet": the story's claims say nothing about it.
  final bool reported;
}
