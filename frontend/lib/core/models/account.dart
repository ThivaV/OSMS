import 'item.dart';
import 'source.dart';

/// Ways to sign in. All go through Firebase Authentication; OSMS never sees a
/// password. Hackathon scope is Google only.
enum SignInProvider {
  google('Google'),
  apple('Apple'),
  github('GitHub'),
  microsoft('Microsoft'),
  emailLink('email');

  const SignInProvider(this.label);
  final String label;
}

class User {
  const User({required this.id, required this.displayName, required this.email, required this.language});

  final String id;
  final String displayName;
  final String email;
  final String language;
}

/// An interface language OSMS can summarise in.
class AppLanguage {
  const AppLanguage({required this.code, required this.nativeName, required this.englishName});

  final String code;
  final String nativeName;
  final String englishName;
}

/// An onboarding topic: a folder of the seed source list.
class Topic {
  const Topic({required this.id, required this.name, required this.description});

  final String id;
  final String name;
  final String description;
}

/// A source offered during onboarding for a topic.
class SourceSuggestion {
  const SourceSuggestion({required this.source, required this.topicId, required this.kind, this.note});

  final Source source;
  final String topicId;

  /// The kind of item it mostly produces.
  final ItemKind kind;

  /// A short line on why it's suggested, e.g. "Weekly, about 6 items".
  final String? note;
}

/// What the add-source box found for a link, handle or OPML file.
class DiscoveredSource {
  const DiscoveredSource({
    required this.source,
    this.latest = const [],
    this.frequency,
    this.folder,
    this.alreadyFollowed = false,
    this.unreachable = false,
  });

  final Source source;
  final List<Item> latest;

  /// How often it publishes, e.g. "about 4 posts a week".
  final String? frequency;

  /// The folder it had in an imported OPML file.
  final String? folder;
  final bool alreadyFollowed;

  /// The feed in an OPML file could not be fetched.
  final bool unreachable;
}
