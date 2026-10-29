import 'auth_client_io.dart' if (dart.library.js_interop) 'auth_client_web.dart' as platform;

/// Which sign-in methods the sign-in service has switched on.
class AuthProviders {
  const AuthProviders({this.google = false, this.emailLink = false});

  final bool google;

  /// Development only: a link printed in the sign-in service's log.
  final bool emailLink;

  bool get any => google || emailLink;
}

/// Who the sign-in service says is signed in.
class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;
}

/// The sign-in service (Better Auth) could not be reached, or refused.
class AuthException implements Exception {
  const AuthException(this.message);

  /// In plain words, for the reader.
  final String message;

  @override
  String toString() => message;
}

/// Talks to OSMS's sign-in service. On the web the session is a cookie the app
/// never sees; on the desktop it is a bearer token kept in the Keychain. Either
/// way the app only ever hands the API a short-lived token from [apiToken].
abstract interface class AuthClient {
  Future<AuthProviders> providers();

  Future<AuthUser?> currentUser();

  /// A token for the OSMS API, valid for 15 minutes. Null when signed out.
  Future<String?> apiToken({bool refresh = false});

  /// Desktop: opens Google in a system sign-in window and returns true once
  /// signed in. Web: sends the browser to Google (it comes back signed in) and
  /// returns false.
  Future<bool> signInWithGoogle();

  /// Development only: asks for a sign-in link for [email].
  Future<void> sendEmailLink(String email);

  Future<void> signOut();

  /// Deletes the sign-in account. The API deletes OSMS's data about the reader first.
  Future<void> deleteAccount();
}

AuthClient createAuthClient(Uri base) => platform.createAuthClient(base);
