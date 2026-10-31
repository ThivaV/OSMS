/// One model decision behind a story, from the decision log: which agent, which model
/// (and any backup), what it said and what it changed. Never anything about a reader.
class Decision {
  const Decision({
    required this.id,
    required this.agent,
    required this.model,
    required this.at,
    this.fallback,
    this.latency,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.about,
    this.source,
    this.reason,
    this.outcome,
  });

  final String id;

  /// triage, judge, claims, verifier, writer or illustration.
  final String agent;
  final String model;

  /// The backup model that answered instead.
  final String? fallback;
  final DateTime at;
  final Duration? latency;
  final int inputTokens;
  final int outputTokens;

  /// The item it decided about, and its source; null when about the story itself.
  final String? about;
  final String? source;
  final String? reason;
  final String? outcome;

  /// What the step does, in plain words.
  String get step => switch (agent) {
    'triage' => 'Checked the item',
    'judge' => 'Same story?',
    'claims' => 'Found the facts',
    'verifier' => 'Checked the facts',
    'writer' => 'Wrote the summary',
    'illustration' => 'Drew the illustration',
    _ => agent,
  };

  /// The model that actually decided, by its product name.
  String get decidedBy => modelName(fallback ?? model);

  static String modelName(String id) => switch (id) {
    'muse-spark-1.3' => 'Muse Spark',
    'muse-spark-open-1026' => 'Muse Spark Open',
    'muse-glimmer-30b' => 'Muse Glimmer',
    'muse-wonder-1.0' => 'Muse Wonder',
    'muse-image-1.0' => 'Muse Image',
    _ => id,
  };
}
