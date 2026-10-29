/// Where the app finds its services. Set with `--dart-define`; the defaults suit
/// local development (`make auth`, `make api`). Nothing here is secret.
abstract final class Env {
  /// The sign-in service (Better Auth).
  static final authUrl = Uri.parse(const String.fromEnvironment('OSMS_AUTH_URL', defaultValue: 'http://localhost:3000'));

  /// The OSMS API.
  static final apiUrl = Uri.parse(const String.fromEnvironment('OSMS_API_URL', defaultValue: 'http://localhost:8000'));

  /// Shown on "What OSMS keeps". Empty hides the line.
  static const privacyContact = String.fromEnvironment('OSMS_PRIVACY_CONTACT');
}
