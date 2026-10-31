# Spec: sign-up and sign-in, end to end (Oct 29)

**Goal:** a reader creates an account or signs in with Google, on the web and on macOS,
goes through onboarding once, and lands on Today with their own topics, sources and
research interests. "Delete my account" removes everything. Open source throughout:
[Better Auth](https://better-auth.com) (MIT) instead of a hosted sign-in service.

## Inputs

- `.env` (names in `.env.example`): `BETTER_AUTH_SECRET` (from `make env`),
  `BETTER_AUTH_URL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `OSMS_APP_ORIGINS`,
  `OSMS_API_AUDIENCE`, `OSMS_DEV_SIGN_IN`.
- A Google OAuth client (web application) with redirect URI
  `<BETTER_AUTH_URL>/api/auth/callback/google`. Without it, Google sign-in is off.
- The seed source list (`backend/seed/sources.opml`): onboarding's topics and suggestions.

## Outputs

- **`auth/`**: Better Auth on Node, users and sessions in `data/auth.db`. Routes:
  `/api/auth/*` (Better Auth), `/providers` (which methods are on), `/native/sign-in`
  and `/native/done` (the macOS hand-off), `/health`.
- **`backend/`**: `GET /onboarding/options`, `GET /me`, `PUT /me/onboarding`,
  `PUT /me/interests`, `PATCH /me/settings`, `DELETE /me`, `GET /health`. Readers and
  their picks in `data/osms.db` (Alembic migration `0001`).
- **`frontend/`**: the real app. Session and routing (Riverpod, go_router), sign-in,
  onboarding, Today, Settings, research interests, "What OSMS keeps". Signed in, only
  the reader's own stories: an empty Today until OSMS collects them, which with no
  sources offers onboarding again to choose some. Signed out, the demo's invented sample
  stories, under a banner that says so.

## Rules

- The API accepts only EdDSA JWTs from the auth service's JWKS, for audience
  `osms-api`, unexpired; the reader's id is `sub`. Every query filters by it (rule 7).
- Web sessions are HttpOnly cookies on the auth service; the app never reads them. The
  macOS session token lives in the Keychain (legacy keychain, so no Keychain Sharing
  entitlement or provisioning profile).
- macOS signs in in the reader's default browser and listens on the loopback interface
  for the answer (RFC 8252). The hand-off token is one-time, three minutes, stored
  hashed, minted only by the server after a real sign-in, sent only to
  `http://127.0.0.1:<port>/callback?state=<random>` (that exact shape), and only for a
  sign-in the same browser started (flow cookie). The app accepts only its own state.
- Development sign-in (`OSMS_DEV_SIGN_IN=1`) is refused in production; its links go to
  the local log, and the address never does.
- CORS and redirects only for `OSMS_APP_ORIGINS`. Inputs are strict: known values,
  capped sizes, unknown fields refused.
- Deleting an account: the API deletes OSMS's data first, then Better Auth deletes the
  account and its sessions. If the second step fails, the reader is told.

## How to test

- `make check-auth`: the real auth server on an in-memory database. It covers which
  methods are on, CORS, API tokens verified against the published keys, signed bearer
  tokens only, the desktop hand-off (only to the app's loopback address, only for a
  sign-in the browser started, once), no client-minted hand-off tokens, and unsafe
  settings refused.
- `make check-backend`: any token that isn't valid is refused (wrong audience, issuer,
  key or algorithm, expired, `none`); first sign-in creates the reader; onboarding,
  settings and interests saved and validated; one reader never sees another's data;
  deletion removes everything the reader owns and keeps shared sources.
- `make check-flutter`: the app's flows against fake clients. They cover the demo
  signed out (labelled samples), first sign-in to onboarding to an empty Today with no
  samples, skipping onboarding and choosing sources again from the empty Today, a
  returning reader, the dev email link, sign-in down, and "Delete my account". The macOS sign-in
  client against a real loopback listener and a fake browser: success, a stranger's
  answer refused, cancelled, a forged token, no answer, no browser, sign-out. The macOS
  menu bar through its platform channel.
- `make test-macos` (with `make up` running): the real macOS app in its sandbox reaches
  sign-in and the API, keeps a session in the Keychain, listens on 127.0.0.1, signs in
  through the real desktop hand-off (a development session stands in for Google), then
  onboards, reaches an empty Today and Settings, and deletes its account. Saves
  screenshots. Since Oct 31 the same target also plays a briefing in the real app
  (`integration_test/briefing_audio_test.dart`), one test file at a time.
- By hand: `make up`, open http://localhost:8080, **Create an account**, then
  **Email me a sign-in link** and open the link from the `auth` log. On macOS, **Continue
  with Google** in the app.

## Not yet

- Google's own page in the macOS round trip, checked by hand. Developer ID signing and
  notarisation, to share the app. A consent screen that admits any Google account. Real
  stories, in the empty Today and in place of the demo's samples. Editing picks from
  settings (onboarding again for now).
