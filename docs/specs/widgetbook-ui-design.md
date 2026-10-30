# Spec: Widgetbook UI design (phase 1)

**Goal:** design the OSMS components in Widgetbook with fake data, before the backend
exists, so the look can be reviewed and changed cheaply.

## Inputs

Invented fixtures only, in `frontend/lib/sample/` (re-exported by
`frontend/widgetbook/lib/fixtures/`): users, sources of every
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

## Oct 30 additions (same rules)

- `AskStoryBox` (AGENTS.md §10 item 20, spec `docs/specs/ask-story.md`): one use
  case per state (Answered, Idle, Thinking, Not reported, Unavailable) plus a
  Live case that thinks, then answers or reports nothing — a state machine
  shows better per-state than in the Normal/Empty/Extreme trilogy.
- `SourcesSidebar.onSelect`: Today, topic, source and Saved rows drive the
  story list (research interests route to `/interests`); rows with nowhere to
  go stay inert, never dead taps.
- `CommandPalette`: hover follows the highlight, keyboard travel keeps the row
  on screen, the highlight clamps as the list shrinks with the query.

## How to test

- `flutter analyze` in `frontend/` and `frontend/widgetbook/`: no issues.
- `flutter test` in `frontend/widgetbook/`: every component renders at phone, tablet and
  desktop widths, in light and dark, without layout errors; the main screens render in
  every theme.
- `flutter test` in `frontend/`: every palette meets WCAG contrast.
- `flutter run -d chrome` in `frontend/widgetbook/` to review the designs.
