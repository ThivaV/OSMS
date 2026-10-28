class BriefingChapter {
  const BriefingChapter({
    required this.storyId,
    required this.title,
    required this.duration,
    this.newFactCount = 0,
  });

  final String storyId;
  final String title;
  final Duration duration;
  final int newFactCount;
}

/// The morning audio briefing: one chapter per story.
class Briefing {
  const Briefing({required this.date, required this.chapters});

  final DateTime date;
  final List<BriefingChapter> chapters;

  Duration get duration => chapters.fold(Duration.zero, (sum, c) => sum + c.duration);
}
