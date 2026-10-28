import 'package:flutter/material.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/features/briefing/briefing_player.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;
import 'frame.dart';

const _width = 520.0;

@widgetbook.UseCase(name: 'Normal', type: BriefingPlayer, path: '[Briefing]')
Widget briefingNormal(BuildContext context) => Frame(
  maxWidth: _width,
  child: Variants(
    children: {
      'Full player': BriefingPlayer(briefing: fx.briefing, initialChapter: 1),
      'Mini player (sidebar, bottom bar)': BriefingMiniPlayer(briefing: fx.briefing, chapter: 1),
    },
  ),
);

@widgetbook.UseCase(name: 'Empty', type: BriefingPlayer, path: '[Briefing]')
Widget briefingEmpty(BuildContext context) => Frame(
  maxWidth: _width,
  child: Variants(
    children: {
      'Before the first briefing': const BriefingPlayer(briefing: null),
      'Mini player with no chapters': BriefingMiniPlayer(briefing: Briefing(date: DateTime.now(), chapters: const [])),
    },
  ),
);

@widgetbook.UseCase(name: 'Extreme content', type: BriefingPlayer, path: '[Briefing]')
Widget briefingExtreme(BuildContext context) =>
    Frame(maxWidth: _width, child: BriefingPlayer(briefing: fx.extremeBriefing, initialChapter: 12));
