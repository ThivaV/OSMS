// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:osms_widgetbook/use_cases/accounts.dart'
    as _osms_widgetbook_use_cases_accounts;
import 'package:osms_widgetbook/use_cases/briefing.dart'
    as _osms_widgetbook_use_cases_briefing;
import 'package:osms_widgetbook/use_cases/foundations.dart'
    as _osms_widgetbook_use_cases_foundations;
import 'package:osms_widgetbook/use_cases/layout.dart'
    as _osms_widgetbook_use_cases_layout;
import 'package:osms_widgetbook/use_cases/modern.dart'
    as _osms_widgetbook_use_cases_modern;
import 'package:osms_widgetbook/use_cases/onboarding.dart'
    as _osms_widgetbook_use_cases_onboarding;
import 'package:osms_widgetbook/use_cases/settings.dart'
    as _osms_widgetbook_use_cases_settings;
import 'package:osms_widgetbook/use_cases/sources.dart'
    as _osms_widgetbook_use_cases_sources;
import 'package:osms_widgetbook/use_cases/story_card.dart'
    as _osms_widgetbook_use_cases_story_card;
import 'package:osms_widgetbook/use_cases/story_sections.dart'
    as _osms_widgetbook_use_cases_story_sections;
import 'package:widgetbook/widgetbook.dart' as _widgetbook;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookCategory(
    name: 'Accounts',
    children: [
      _widgetbook.WidgetbookComponent(
        name: 'AccountRow',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_accounts.accountEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_accounts.accountExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_accounts.accountNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'DemoBanner',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_accounts.demoBannerEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_accounts.demoBannerExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_accounts.demoBannerNormal,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Real stories',
            builder: _osms_widgetbook_use_cases_accounts.demoBannerReal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'SettingsPage',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_settings.settingsEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_settings.settingsExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_settings.settingsNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'SignInPage',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_accounts.signInEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_accounts.signInExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_accounts.signInNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'WhatWeKeepPage',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_accounts.whatWeKeepEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_accounts.whatWeKeepExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_accounts.whatWeKeepNormal,
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookCategory(
    name: 'Briefing',
    children: [
      _widgetbook.WidgetbookComponent(
        name: 'BriefingPlayer',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_briefing.briefingEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_briefing.briefingExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_briefing.briefingNormal,
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookCategory(
    name: 'Foundations',
    children: [
      _widgetbook.WidgetbookComponent(
        name: 'DesignTokens',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Colours, type, spacing',
            builder: _osms_widgetbook_use_cases_foundations.designTokens,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'ThemePicker',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_settings.themePickerEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_settings.themePickerExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_settings.themePickerNormal,
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookCategory(
    name: 'Layout',
    children: [
      _widgetbook.WidgetbookComponent(
        name: 'CommandPalette',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_modern.paletteEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_modern.paletteExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_modern.paletteNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'PillNav',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_modern.floatingEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_modern.floatingExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_modern.floatingNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'ThreePaneLayout',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_layout.shellEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_layout.shellExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_layout.shellNormal,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Reading a story',
            builder: _osms_widgetbook_use_cases_layout.shellReading,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Signed out: click through sign-in',
            builder: _osms_widgetbook_use_cases_layout.shellSignedOut,
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookCategory(
    name: 'Onboarding',
    children: [
      _widgetbook.WidgetbookComponent(
        name: 'Onboarding',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_onboarding.onboardingEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_onboarding.onboardingExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_onboarding.onboardingNormal,
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookCategory(
    name: 'Sources',
    children: [
      _widgetbook.WidgetbookComponent(
        name: 'AddSourceSheet',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_sources.addSourceEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_sources.addSourceExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_sources.addSourceNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'InterestsEditor',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_sources.interestsEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_sources.interestsExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_sources.interestsNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'ItemCard',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_sources.itemCardEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_sources.itemCardExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_sources.itemCardNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'SourceChip',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_sources.sourceChipEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_sources.sourceChipExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_sources.sourceChipNormal,
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookCategory(
    name: 'Story',
    children: [
      _widgetbook.WidgetbookComponent(
        name: 'AskStoryBox',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Answered',
            builder: _osms_widgetbook_use_cases_story_sections.askAnswered,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Idle',
            builder: _osms_widgetbook_use_cases_story_sections.askIdle,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Live',
            builder: _osms_widgetbook_use_cases_story_sections.askLive,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Not reported',
            builder: _osms_widgetbook_use_cases_story_sections.askNotReported,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Thinking',
            builder: _osms_widgetbook_use_cases_story_sections.askThinking,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Unavailable',
            builder: _osms_widgetbook_use_cases_story_sections.askUnavailable,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'DecisionLogSection',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Before loading',
            builder: _osms_widgetbook_use_cases_story_sections
                .decisionsBeforeLoading,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Decisions',
            builder: _osms_widgetbook_use_cases_story_sections.decisionsShown,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'None yet',
            builder: _osms_widgetbook_use_cases_story_sections.decisionsNone,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'DisagreementPanel',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder:
                _osms_widgetbook_use_cases_story_sections.disagreementEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder:
                _osms_widgetbook_use_cases_story_sections.disagreementExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder:
                _osms_widgetbook_use_cases_story_sections.disagreementNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'SourceQuote',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_story_sections.sourceQuoteEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder:
                _osms_widgetbook_use_cases_story_sections.sourceQuoteExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder:
                _osms_widgetbook_use_cases_story_sections.sourceQuoteNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'StoryCard',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_story_card.storyCardEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Every story',
            builder: _osms_widgetbook_use_cases_story_card.storyCardAll,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_story_card.storyCardExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_story_card.storyCardNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'StoryDetailView',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_story_sections.storyPageEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_story_sections.storyPageExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_story_sections.storyPageNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'StoryTimeline',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_story_sections.timelineEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_story_sections.timelineExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_story_sections.timelineNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'TodayOverview',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_modern.todayEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Empty, sources followed',
            builder: _osms_widgetbook_use_cases_modern.todayWaiting,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_modern.todayExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_modern.todayNormal,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'WhatsNewSection',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Empty',
            builder: _osms_widgetbook_use_cases_story_sections.whatsNewEmpty,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Extreme content',
            builder: _osms_widgetbook_use_cases_story_sections.whatsNewExtreme,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Normal',
            builder: _osms_widgetbook_use_cases_story_sections.whatsNewNormal,
          ),
        ],
      ),
    ],
  ),
];
