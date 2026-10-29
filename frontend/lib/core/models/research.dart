/// An arXiv subject category, e.g. `cs.CL`.
class ArxivCategory {
  const ArxivCategory({required this.code, required this.name});

  final String code;
  final String name;
}

/// The categories offered in the picker: science and technology only (rule 3).
/// cs.CY and physics.soc-ph are left out because they often cover policy.
const arxivCategories = [
  ArxivCategory(code: 'cs.AI', name: 'Artificial Intelligence'),
  ArxivCategory(code: 'cs.CL', name: 'Computation and Language'),
  ArxivCategory(code: 'cs.LG', name: 'Machine Learning'),
  ArxivCategory(code: 'cs.CV', name: 'Computer Vision'),
  ArxivCategory(code: 'cs.IR', name: 'Information Retrieval'),
  ArxivCategory(code: 'cs.RO', name: 'Robotics'),
  ArxivCategory(code: 'cs.SE', name: 'Software Engineering'),
  ArxivCategory(code: 'cs.PL', name: 'Programming Languages'),
  ArxivCategory(code: 'cs.HC', name: 'Human-Computer Interaction'),
  ArxivCategory(code: 'stat.ML', name: 'Machine Learning (Statistics)'),
  ArxivCategory(code: 'eess.AS', name: 'Audio and Speech Processing'),
  ArxivCategory(code: 'q-bio.BM', name: 'Biomolecules'),
  ArxivCategory(code: 'quant-ph', name: 'Quantum Physics'),
  ArxivCategory(code: 'cond-mat.mtrl-sci', name: 'Materials Science'),
  ArxivCategory(code: 'astro-ph.EP', name: 'Earth and Planetary Astrophysics'),
  ArxivCategory(code: 'astro-ph.IM', name: 'Astrophysics Instrumentation'),
];

/// What the reader typed and picked in the interests editor, before it is saved.
class InterestDraft {
  const InterestDraft({required this.keywords, this.relatedTerms = const [], this.categories = const []});

  final List<String> keywords;
  final List<String> relatedTerms;
  final List<String> categories;

  bool get isEmpty => keywords.isEmpty;
}

/// A reader's research interest on arXiv: keywords, the related terms they
/// accepted from the interest agent, and optional categories.
class ResearchInterest {
  const ResearchInterest({
    required this.id,
    required this.keywords,
    this.relatedTerms = const [],
    this.categories = const [],
    this.newThisWeek = 0,
  });

  final String id;
  final List<String> keywords;
  final List<String> relatedTerms;
  final List<String> categories;

  /// Papers matched in the last seven days.
  final int newThisWeek;

  /// `retrieval-augmented generation +1`
  String get label => keywords.isEmpty
      ? 'Untitled interest'
      : keywords.length == 1
      ? keywords.first
      : '${keywords.first} +${keywords.length - 1}';
}
