import 'story.dart';

class BriefingChapter {
  const BriefingChapter({
    required this.storyId,
    required this.title,
    required this.duration,
    this.newFactCount = 0,
    this.start,
    this.sentences = const [],
  });

  final String storyId;
  final String title;
  final Duration duration;
  final int newFactCount;

  /// Where the chapter starts in the briefing's audio. Null for samples, whose
  /// chapters run back to back.
  final Duration? start;

  /// What the chapter says, sentence by sentence, each with the sources behind it.
  final List<SummaryPoint> sentences;
}

/// The morning audio briefing: one chapter per story.
class Briefing {
  const Briefing({required this.date, required this.chapters, this.id, this.audioUrl, this.total});

  final DateTime date;
  final List<BriefingChapter> chapters;

  /// Null for samples, which have no audio.
  final String? id;

  /// Signed and short-lived: only this briefing's reader is given it.
  final String? audioUrl;

  /// The whole recording, intro and pauses included; samples add up their chapters.
  final Duration? total;

  Duration get duration => total ?? chapters.fold(Duration.zero, (sum, c) => sum + c.duration);

  Duration startOf(int chapter) =>
      chapters[chapter].start ?? chapters.take(chapter).fold(Duration.zero, (sum, c) => sum + c.duration);

  /// The chapter playing at [position]: the intro counts as the first.
  int chapterAt(Duration position) {
    var found = 0;
    for (var i = 0; i < chapters.length; i++) {
      if (startOf(i) <= position) found = i;
    }
    return found;
  }
}
