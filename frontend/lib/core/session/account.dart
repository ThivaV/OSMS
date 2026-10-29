import '../../shared/widgets/story_card.dart';
import '../models/models.dart';
import '../theme/appearance.dart';

/// The signed-in reader as the OSMS API knows them: profile, picks and settings.
class Account {
  const Account({
    required this.user,
    this.topics = const [],
    this.kinds = const {},
    this.subscriptions = const [],
    this.interests = const [],
    this.appearance,
    this.defaultLayout,
    this.onboarded = false,
  });

  final User user;
  final List<Topic> topics;
  final Set<ItemKind> kinds;
  final List<Source> subscriptions;
  final List<ResearchInterest> interests;

  /// Null until the reader changes something in Settings.
  final Appearance? appearance;
  final StoryCardLayout? defaultLayout;

  /// False until onboarding is finished or skipped: the first sign-in goes there.
  final bool onboarded;

  Account copyWith({Appearance? appearance, StoryCardLayout? defaultLayout, String? language}) => Account(
    user: language == null
        ? user
        : User(id: user.id, displayName: user.displayName, email: user.email, language: language),
    topics: topics,
    kinds: kinds,
    subscriptions: subscriptions,
    interests: interests,
    appearance: appearance ?? this.appearance,
    defaultLayout: defaultLayout ?? this.defaultLayout,
    onboarded: onboarded,
  );
}

/// What onboarding offers: from the seed source list, through the API.
class OnboardingOptions {
  const OnboardingOptions({required this.languages, required this.topics, required this.suggestions});

  final List<AppLanguage> languages;
  final List<Topic> topics;
  final List<SourceSuggestion> suggestions;
}
