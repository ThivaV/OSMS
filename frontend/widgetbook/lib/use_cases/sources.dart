import 'package:flutter/material.dart';
import 'package:osms/core/models/models.dart';
import 'package:osms/core/theme/tokens.dart';
import 'package:osms/features/sources/add_source_sheet.dart';
import 'package:osms/features/sources/interests_editor.dart';
import 'package:osms/shared/widgets/item_card.dart';
import 'package:osms/shared/widgets/source_chip.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;
import 'frame.dart';

// ── Source chip ──────────────────────────────────────────────────────────────

const _oneOfEachType = [
  fx.arxivCsCl,
  fx.orbitalWeekly,
  fx.inferenceBrief,
  fx.gradientHour,
  fx.tinkerersAudio,
  fx.launchpadLens,
  fx.adaRowan,
  fx.junoVale,
  fx.modelTinkerers,
  fx.kodehjornet,
  fx.miraHolt,
  fx.debugDuck,
  fx.techMadal,
];

@widgetbook.UseCase(name: 'Normal', type: SourceChip, path: '[Sources]')
Widget sourceChipNormal(BuildContext context) {
  final showLanguage = context.knobs.boolean(label: 'Show language', initialValue: true);
  return Frame(
    child: Variants(
      children: {
        'One of each source type (ticked = you follow it)': Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final s in _oneOfEachType) SourceChip(source: s, showLanguage: showLanguage, onTap: () {}),
          ],
        ),
        'Avatar stack': Row(children: [SourceStack(sources: fx.halcyon.sources)]),
        'Avatars': Wrap(
          spacing: Space.sm,
          children: [for (final s in _oneOfEachType.take(6)) SourceAvatar(source: s, size: Sizes.avatarLg)],
        ),
      },
    ),
  );
}

@widgetbook.UseCase(name: 'Empty', type: SourceChip, path: '[Sources]')
Widget sourceChipEmpty(BuildContext context) => const Frame(
  child: Variants(
    children: {
      'Name without letters or digits': SourceChip(
        source: Source(id: 'symbols', name: '—', type: SourceType.feed, language: 'en'),
      ),
      'No sources in a stack': SourceStack(sources: []),
    },
  ),
);

@widgetbook.UseCase(name: 'Extreme content', type: SourceChip, path: '[Sources]')
Widget sourceChipExtreme(BuildContext context) => Frame(
  child: Variants(
    children: {
      'Very long name': const SourceChip(
        source: Source(
          id: 'long',
          name: 'A Publication With An Extraordinarily Long Name For A Chip',
          type: SourceType.newsletter,
          language: 'da',
          followed: true,
        ),
      ),
      '40 sources': Wrap(
        spacing: Space.xs,
        runSpacing: Space.xs,
        children: [for (final s in fx.manySources(40)) SourceChip(source: s)],
      ),
      'Stack of 40': SourceStack(sources: fx.manySources(40)),
    },
  ),
);

// ── Item card ────────────────────────────────────────────────────────────────

Widget _itemList(List<Item> items) => Frame(
  child: Variants(
    children: {
      for (final (i, item) in items.indexed)
        '${i + 1}. ${item.kind.singular} from ${item.source.type.label}': ItemCard(item: item, onTap: () {}),
    },
  ),
);

@widgetbook.UseCase(name: 'Normal', type: ItemCard, path: '[Sources]')
Widget itemCardNormal(BuildContext context) => _itemList(fx.items);

@widgetbook.UseCase(name: 'Empty', type: ItemCard, path: '[Sources]')
Widget itemCardEmpty(BuildContext context) => _itemList(fx.emptyItems);

@widgetbook.UseCase(name: 'Extreme content', type: ItemCard, path: '[Sources]')
Widget itemCardExtreme(BuildContext context) => _itemList(fx.extremeItems);

// ── Add a source ─────────────────────────────────────────────────────────────

const _sheetWidth = Sizes.sheetMaxWidth;

@widgetbook.UseCase(name: 'Normal', type: AddSourceSheet, path: '[Sources]')
Widget addSourceNormal(BuildContext context) {
  final status = context.knobs.object.dropdown(
    label: 'State',
    options: const [AddSourceStatus.found, AddSourceStatus.searching, AddSourceStatus.notFound, AddSourceStatus.opml],
    labelBuilder: (s) => s.name,
  );
  return Frame(
    maxWidth: _sheetWidth,
    child: AddSourceSheet(
      key: ValueKey(status),
      status: status,
      query: 'https://labnotes.example',
      found: fx.foundSource,
      opmlFileName: 'reader-export.opml',
      opmlSources: fx.opmlSources(18),
      onFollowResearch: () {},
    ),
  );
}

@widgetbook.UseCase(name: 'Empty', type: AddSourceSheet, path: '[Sources]')
Widget addSourceEmpty(BuildContext context) => const Frame(maxWidth: _sheetWidth, child: AddSourceSheet());

@widgetbook.UseCase(name: 'Extreme content', type: AddSourceSheet, path: '[Sources]')
Widget addSourceExtreme(BuildContext context) => Frame(
  maxWidth: _sheetWidth,
  child: AddSourceSheet(
    status: AddSourceStatus.opml,
    opmlFileName: 'a-very-long-export-file-name-from-another-reader-2026-10-28.opml',
    opmlSources: fx.opmlSources(120),
  ),
);

// ── Research interests (arXiv) ───────────────────────────────────────────────

@widgetbook.UseCase(name: 'Normal', type: InterestsEditor, path: '[Sources]')
Widget interestsNormal(BuildContext context) => Frame(
  maxWidth: _sheetWidth,
  child: InterestsEditor(
    initialKeywords: fx.interests.first.keywords,
    suggestedTerms: fx.researchSuggestions,
    initialRelated: fx.interests.first.relatedTerms.toSet(),
    initialCategories: fx.interests.first.categories.toSet(),
    preview: fx.research.take(3).toList(),
    previewCount: 46,
    onSave: (_) {},
    onClose: () {},
  ),
);

@widgetbook.UseCase(name: 'Empty', type: InterestsEditor, path: '[Sources]')
Widget interestsEmpty(BuildContext context) =>
    Frame(maxWidth: _sheetWidth, child: InterestsEditor(onSave: (_) {}, onClose: () {}));

@widgetbook.UseCase(name: 'Extreme content', type: InterestsEditor, path: '[Sources]')
Widget interestsExtreme(BuildContext context) => Frame(
  maxWidth: _sheetWidth,
  child: InterestsEditor(
    initialKeywords: fx.extremeKeywords,
    suggestedTerms: [...fx.researchSuggestions, ...fx.extremeKeywords.take(8)],
    initialCategories: {for (final c in arxivCategories) c.code},
    flagged: fx.flaggedKeywords,
    preview: [fx.extremePaper, ...fx.research],
    previewCount: 2000,
    onSave: (_) {},
    onClose: () {},
  ),
);
