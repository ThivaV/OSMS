# Spec: Design polish + project health (Oct 29)

**Goal:** close the gaps found reviewing the Widgetbook phase (fake-data UI done,
backend next), without changing the frozen look (ink interaction, violet = new,
neutral disagreements, tokens-only, no copied reader UI).

## Design inputs

Existing components in `frontend/lib/`, fixtures in
`frontend/widgetbook/lib/fixtures/`, use cases in
`frontend/widgetbook/lib/use_cases/`.

## Design outputs (all in Widgetbook, all with Normal/Empty/Extreme)

1. `StoryVisual`: new `isIllustration` flag. When true, a small
   "Illustration" pill sits bottom-left over the art (spec: Muse Image art is
   always labelled; the drawn threads stay the unlabeled fallback). Since Oct 31,
   `imageUrl` and `focus` show the checked illustration itself, cropped around its
   subject, with the drawn art while it loads and if it can't.
2. `ItemCard` thumbnails: stop reusing the multi-thread `StoryVisual` for a
   single item. Neutral `surfaceSunken` placeholder with the kind glyph (play
   overlay + duration for video/episode). Honest until real thumbnails arrive
   from the backend.
3. `StoryCard` (card layout): replace the full `Divider` with a hairline in
   `border` colour, tighten the gap above sources, and show `NewFactsBadge`
   only when `newFactCount > 0` (matches the row layout; grids stay quiet).
4. `WhatsNewSection`: hairline border in `newSignal` at low alpha around the
   tinted container, so it holds its shape on both themes.
5. Story toolbar: the disagree jump stays enabled and scrolls to the
   "Sources agree so far" note when there is nothing to show. No dead button.
6. `TodayOverview` empty state: add `onAddSource` and a real CTA
   ("Add a source"), matching `StoryList`'s empty state.

## Not in scope

New palettes, new view modes, real images/audio, API wiring, translations.

## Project outputs

- `.env.example`: add the names AGENTS.md already implies (Firebase web
  config at the time, replaced by Better Auth's names later on Oct 29, see
  `sign-in.md`; TTS pick, search API placeholder, arXiv contact) — names only.
- `/.github/workflows/check.yml`: `flutter analyze` + `flutter test` (app +
  Widgetbook) and backend `ruff` + `pytest`. What judging calls technical
  depth starts with a green main.
- `README.md`: fill "What was built" with the Widgetbook milestone + where
  to click, and a judging-criteria pointer.

## How to test

- `cd frontend && flutter analyze && flutter test`
- `cd frontend/widgetbook && flutter analyze && flutter test`
- `flutter run -d chrome` in `frontend/widgetbook/`: check StoryVisual label,
  ItemCard placeholders, card spacing, empty Today CTA, toolbar with zero
  disagreements, light/dark + phone/tablet/desktop.
