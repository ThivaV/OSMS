# Spec: Widgetbook UI design (phase 1)

**Goal:** design the OSMS components in Widgetbook with fake data, before the backend
exists, so the look can be reviewed and changed cheaply.

## Inputs

Invented fixtures only, in `frontend/widgetbook/lib/fixtures/`: users, sources of every
type, items of every kind (papers included), stories, claims, disagreements, timeline
events, briefings, topics, onboarding suggestions, research interests and suggested
terms. Reserved `.example` domains, non-political topics, no real people, accounts or
publications. Fake papers use invented authors, ids like `2610.9xxxx` and
`arxiv.example` links.

## Outputs

- **Design tokens** in `frontend/lib/core/theme/`: colours, type scale, spacing, radii and
  durations, for light and dark. Components use tokens only, never raw values.
- **Breakpoints and `ThreePaneLayout`** in `frontend/lib/core/layout/`.
- **Plain data models** in `frontend/lib/core/models/` (no JSON or API code yet).
- **Components**, each with *Normal*, *Empty* and *Extreme content* use cases:
  `StoryCard`, `WhatsNewSection`, `DisagreementPanel`, `StoryTimeline`, `BriefingPlayer`,
  `SourceChip`, `ThreePaneLayout`, `ItemCard`, `AddSourceSheet`, `Onboarding`,
  `SignInPage`, `WhatWeKeepPage`, `AccountRow`, `DemoBanner`, `SettingsPage`, `ThemePicker`,
  `TodayOverview`, `PillNav`, `CommandPalette` and `InterestsEditor`. `ItemCard` has a
  paper variant; `TodayOverview` has a "New research for you" section.
- **Themes:** five palettes (Folio, Fjord, Clay, Nordlys, High contrast), each light and
  dark, plus pure black; every one passes a WCAG contrast test.
- **A clickable sign-in flow** in the shell: demo → sign in or create account →
  onboarding (with the research step when a research topic is picked) → Today (sign-in
  is simulated). "Follow research on arXiv" in ⌘K or Settings opens the interests
  editor.
- **Addons:** light/dark theme, phone/tablet/desktop viewports, text scale.

## Not in scope

API calls, state management, routing, real audio playback, translations of the UI.

## How to test

- `flutter analyze` in `frontend/` and `frontend/widgetbook/`: no issues.
- `flutter test` in `frontend/widgetbook/`: every component renders at phone, tablet and
  desktop widths, in light and dark, without layout errors; the main screens render in
  every theme.
- `flutter test` in `frontend/`: every palette meets WCAG contrast.
- `flutter run -d chrome` in `frontend/widgetbook/` to review the designs.
