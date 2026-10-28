# Spec: Widgetbook UI design (phase 1)

**Goal:** design the OSMS components in Widgetbook with fake data, before the backend
exists, so the look can be reviewed and changed cheaply.

## Inputs

Invented fixtures only, in `frontend/widgetbook/lib/fixtures/`: users, sources of every
type, items of every kind, stories, claims, disagreements, timeline events, briefings,
topics and onboarding suggestions. Reserved `.example` domains, non-political topics,
no real people, accounts or publications.

## Outputs

- **Design tokens** in `frontend/lib/core/theme/`: colours, type scale, spacing, radii and
  durations, for light and dark. Components use tokens only, never raw values.
- **Breakpoints and `ThreePaneLayout`** in `frontend/lib/core/layout/`.
- **Plain data models** in `frontend/lib/core/models/` (no JSON or API code yet).
- **Components**, each with *Normal*, *Empty* and *Extreme content* use cases:
  `StoryCard`, `WhatsNewSection`, `DisagreementPanel`, `StoryTimeline`, `BriefingPlayer`,
  `SourceChip`, `ThreePaneLayout`, `ItemCard`, `AddSourceSheet`, `Onboarding`,
  `SignInPage`, `WhatWeKeepPage`, `AccountRow`, `DemoBanner`, `SettingsPage`, `ThemePicker`.
- **Themes:** five palettes (Folio, Fjord, Clay, Nordlys, High contrast), each light and
  dark, plus pure black; every one passes a WCAG contrast test.
- **A clickable sign-in flow** in the shell: demo → sign in or create account →
  onboarding → Today (sign-in is simulated).
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
