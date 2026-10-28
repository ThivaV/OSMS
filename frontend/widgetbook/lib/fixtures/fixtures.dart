// FAKE data for Widgetbook. Every source, person, company, product and handle
// here is invented; domains use the reserved `.example` TLD. Topics stay
// non-political.

import 'package:osms/core/models/models.dart';

DateTime ago({int d = 0, int h = 0, int m = 0}) => DateTime.now().subtract(Duration(days: d, hours: h, minutes: m));

// ── Sources ──────────────────────────────────────────────────────────────────

const orbitalWeekly = Source(
  id: 'orbital-weekly',
  name: 'Orbital Weekly',
  type: SourceType.feed,
  language: 'en',
  url: 'https://orbital-weekly.example/feed',
  followed: true,
);
const inferenceBrief = Source(
  id: 'inference-brief',
  name: 'The Inference Brief',
  type: SourceType.newsletter,
  language: 'en',
  followed: true,
);
const circuitLedger = Source(id: 'circuit-ledger', name: 'Circuit Ledger', type: SourceType.feed, language: 'en');
const fieldnoteScience = Source(
  id: 'fieldnote-science',
  name: 'Fieldnote Science',
  type: SourceType.feed,
  language: 'en',
  followed: true,
);
const byteHarbor = Source(id: 'byte-harbor', name: 'Byte Harbor', type: SourceType.feed, language: 'en');
const siliconTides = Source(id: 'silicon-tides', name: 'Silicon Tides', type: SourceType.feed, language: 'en');
const deepSeaNotes = Source(id: 'deep-sea-notes', name: 'Deep Sea Notes', type: SourceType.feed, language: 'en');
const batteryWeek = Source(id: 'battery-week', name: 'Battery Week', type: SourceType.newsletter, language: 'en');
const gradientHour = Source(
  id: 'gradient-hour',
  name: 'Gradient Hour',
  type: SourceType.podcast,
  language: 'en',
  followed: true,
);
const tinkerersAudio = Source(
  id: 'tinkerers-audio',
  name: 'Tinkerers Audio',
  type: SourceType.soundcloud,
  language: 'en',
);
const launchpadLens = Source(id: 'launchpad-lens', name: 'Launchpad Lens', type: SourceType.youtube, language: 'en');
const teknologiposten = Source(
  id: 'teknologiposten',
  name: 'Teknologiposten',
  type: SourceType.feed,
  language: 'da',
  followed: true,
);
const rumfartIDag = Source(id: 'rumfart-i-dag', name: 'Rumfart i Dag', type: SourceType.feed, language: 'da');
const kodehjornet = Source(id: 'kodehjoernet', name: 'Kodehjørnet', type: SourceType.microblog, language: 'da');
const nordiskStartup = Source(id: 'nordisk-startup', name: 'Nordisk Startup', type: SourceType.feed, language: 'da');

/// A Tamil-language newsletter; also exercises Tamil text rendering.
const techMadal = Source(id: 'tech-madal', name: 'தொழில்நுட்ப மடல்', type: SourceType.newsletter, language: 'ta');
const adaRowan = Source(
  id: 'ada-rowan',
  name: 'Ada Rowan',
  type: SourceType.mastodon,
  language: 'en',
  handle: '@ada@social.example',
  followed: true,
);
const openWeightsTag = Source(
  id: 'openweights-tag',
  name: '#OpenWeights',
  type: SourceType.mastodon,
  language: 'en',
  handle: 'social.example',
);
const junoVale = Source(
  id: 'juno-vale',
  name: 'Juno Vale',
  type: SourceType.bluesky,
  language: 'en',
  handle: '@juno.sky.example',
);
const modelTinkerers = Source(
  id: 'r-modeltinkerers',
  name: 'r/ModelTinkerers',
  type: SourceType.reddit,
  language: 'en',
  handle: 'r/ModelTinkerers',
);
const reusableRockets = Source(
  id: 'r-reusablerockets',
  name: 'r/ReusableRockets',
  type: SourceType.reddit,
  language: 'en',
  handle: 'r/ReusableRockets',
);
const miraHolt = Source(
  id: 'mira-holt',
  name: 'Mira Holt',
  type: SourceType.pixelfed,
  language: 'en',
  handle: '@mira@pix.example',
);
const debugDuck = Source(id: 'debug-duck', name: 'Debug Duck', type: SourceType.comic, language: 'en');
const labNotes = Source(
  id: 'lab-notes',
  name: 'Lab Notes Daily',
  type: SourceType.feed,
  language: 'en',
  url: 'https://labnotes.example/feed',
);

const followedSources = [
  orbitalWeekly,
  inferenceBrief,
  fieldnoteScience,
  gradientHour,
  teknologiposten,
  adaRowan,
];

const _adjectives = ['Quiet', 'Bright', 'Open', 'Northern', 'Parallel', 'Silver', 'Copper', 'Harbour'];
const _nouns = ['Ledger', 'Review', 'Dispatch', 'Notes', 'Wire', 'Journal', 'Digest'];

/// [n] generated sources across every type and all three languages.
List<Source> manySources(int n) => [
  for (var i = 0; i < n; i++)
    Source(
      id: 'gen-$i',
      name: '${_adjectives[i % _adjectives.length]} ${_nouns[(i ~/ _adjectives.length) % _nouns.length]} ${i + 1}',
      type: SourceType.values[i % SourceType.values.length],
      language: const ['en', 'da', 'ta'][i % 3],
      followed: i % 7 == 0,
    ),
];

// ── Stories ──────────────────────────────────────────────────────────────────

final halcyon = Story(
  id: 'halcyon-2',
  title: 'Open-weight model Halcyon-2 tops multilingual benchmarks, including Danish and Tamil',
  summary:
      'Lumen Labs released Halcyon-2, an open-weight language model that leads three multilingual '
      'benchmarks. Sources agree on the benchmark lead but differ on how big the model is and how '
      'permissive its licence is. The weights went up for download yesterday; a smaller 8-bit '
      'version followed this morning.',
  summaryPoints: const [
    SummaryPoint(
      text: 'Lumen Labs released Halcyon-2, an open-weight language model that leads three multilingual benchmarks.',
      sources: [inferenceBrief, circuitLedger, teknologiposten],
    ),
    SummaryPoint(
      text: 'Sources agree on the benchmark lead but differ on how big the model is and how permissive its licence is.',
      sources: [siliconTides, modelTinkerers, byteHarbor],
    ),
    SummaryPoint(
      text: 'The weights went up for download yesterday; a smaller 8-bit version followed this morning.',
      sources: [circuitLedger, adaRowan],
    ),
  ],
  topic: 'AI research',
  updatedAt: ago(h: 2),
  lastReadAt: ago(d: 1, h: 3),
  sources: const [
    inferenceBrief,
    circuitLedger,
    gradientHour,
    teknologiposten,
    techMadal,
    adaRowan,
    openWeightsTag,
    junoVale,
    modelTinkerers,
    byteHarbor,
    tinkerersAudio,
    siliconTides,
    kodehjornet,
    launchpadLens,
  ],
  kindCounts: const {ItemKind.article: 6, ItemKind.episode: 2, ItemKind.video: 1, ItemKind.post: 5},
  languages: const ['en', 'da', 'ta'],
  visualSeed: 11,
  whatsNew: [
    Claim(
      id: 'h-c1',
      text: 'An 8-bit version of the weights is now available, cutting memory use by about half.',
      sources: const [circuitLedger, modelTinkerers],
      reportedAt: ago(h: 3),
    ),
    Claim(
      id: 'h-c2',
      text: 'Lumen Labs published per-language scores. Danish improved the most, by 9 points.',
      sources: const [teknologiposten, inferenceBrief, kodehjornet],
      reportedAt: ago(h: 5),
    ),
  ],
  disagreements: const [
    Disagreement(
      id: 'h-d1',
      topic: 'Parameter count',
      sides: [
        DisagreementSide(
          value: '1.2 trillion',
          claim: 'Total parameters across all experts, as stated in the launch post.',
          sources: [inferenceBrief, circuitLedger, byteHarbor],
        ),
        DisagreementSide(
          value: '900 billion',
          claim: 'Parameters active per token, which some outlets reported as the size.',
          sources: [siliconTides, teknologiposten],
        ),
      ],
    ),
    Disagreement(
      id: 'h-d2',
      topic: 'Licence',
      sides: [
        DisagreementSide(
          value: 'Apache 2.0',
          claim: 'Reported as a standard open-source licence.',
          sources: [circuitLedger, modelTinkerers],
        ),
        DisagreementSide(
          value: 'Custom licence',
          claim: 'Apache-style, but with a cap for services above 50 million users.',
          sources: [inferenceBrief],
        ),
      ],
    ),
  ],
  timeline: [
    TimelineEvent(
      id: 'h-t1',
      at: ago(d: 3, h: 2),
      text: 'Lumen Labs announces Halcyon-2 and a release date.',
      kind: ItemKind.article,
      sourceCount: 3,
    ),
    TimelineEvent(
      id: 'h-t2',
      at: ago(d: 2, h: 6),
      text: 'Early benchmark numbers appear in developer posts.',
      kind: ItemKind.post,
      sourceCount: 6,
    ),
    TimelineEvent(
      id: 'h-t3',
      at: ago(d: 1, h: 8),
      text: 'Weights released for download.',
      kind: ItemKind.article,
      sourceCount: 9,
    ),
    TimelineEvent(
      id: 'h-t4',
      at: ago(h: 5),
      text: 'Per-language scores published.',
      kind: ItemKind.article,
      sourceCount: 3,
    ),
    TimelineEvent(id: 'h-t5', at: ago(h: 3), text: '8-bit weights released.', kind: ItemKind.post, sourceCount: 2),
  ],
);

final kestrel = Story(
  id: 'kestrel',
  title: 'Reusable rocket Kestrel lands at sea for the third time',
  summary:
      'Ardent Launch’s Kestrel booster landed on a drone ship after putting two weather satellites '
      'into orbit, its third flight. Coverage agrees on the outcome but not on the exact landing time.',
  topic: 'Space',
  updatedAt: ago(m: 40),
  lastReadAt: ago(h: 20),
  sources: const [orbitalWeekly, rumfartIDag, launchpadLens, reusableRockets, fieldnoteScience, junoVale],
  kindCounts: const {ItemKind.article: 3, ItemKind.video: 1, ItemKind.post: 2},
  languages: const ['en', 'da'],
  visualSeed: 23,
  whatsNew: [
    Claim(
      id: 'k-c1',
      text: 'Both satellites have sent their first signals.',
      sources: const [orbitalWeekly],
      reportedAt: ago(m: 40),
    ),
  ],
  disagreements: const [
    Disagreement(
      id: 'k-d1',
      topic: 'Landing time',
      sides: [
        DisagreementSide(
          value: '14:02 UTC',
          claim: 'Taken from the live stream.',
          sources: [orbitalWeekly, launchpadLens],
        ),
        DisagreementSide(value: '14:07 UTC', claim: 'Taken from the launch company’s recap.', sources: [rumfartIDag]),
      ],
    ),
  ],
  timeline: [
    TimelineEvent(id: 'k-t1', at: ago(d: 1, h: 2), text: 'Launch window confirmed.', kind: ItemKind.article, sourceCount: 2),
    TimelineEvent(id: 'k-t2', at: ago(h: 6), text: 'Lift-off and booster landing.', kind: ItemKind.video, sourceCount: 5),
    TimelineEvent(id: 'k-t3', at: ago(m: 40), text: 'Satellites send first signals.', kind: ItemKind.article, sourceCount: 1),
  ],
);

final cellcycle = Story(
  id: 'cellcycle',
  title: 'Copenhagen start-up raises €40 million to recycle EV batteries',
  summary:
      'Cellcycle, founded in 2023, will build a plant near Køge that recovers lithium and nickel from '
      'used car batteries. Danish and English coverage agree on the amount; one source puts the '
      'plant’s capacity higher.',
  topic: 'Startups and product',
  updatedAt: ago(h: 5),
  sources: const [teknologiposten, nordiskStartup, batteryWeek, siliconTides],
  kindCounts: const {ItemKind.article: 4},
  languages: const ['da', 'en'],
  visualSeed: 37,
  disagreements: const [
    Disagreement(
      id: 'c-d1',
      topic: 'Plant capacity',
      sides: [
        DisagreementSide(value: '10,000 t a year', claim: 'From the company announcement.', sources: [teknologiposten, nordiskStartup]),
        DisagreementSide(value: '15,000 t a year', claim: 'Quoting an investor’s presentation.', sources: [batteryWeek]),
      ],
    ),
  ],
  timeline: [
    TimelineEvent(id: 'c-t1', at: ago(h: 9), text: 'Funding round announced.', kind: ItemKind.article, sourceCount: 4),
  ],
);

final kiteToolkit = Story(
  id: 'kite-5',
  title: 'Kite UI toolkit 5 cuts web start-up time roughly in half',
  summary:
      'Version 5 of the open-source Kite toolkit ships a new renderer. In the project’s own tests, first '
      'load is about twice as fast; an independent benchmark finds a smaller gain.',
  topic: 'Developer tools',
  updatedAt: ago(h: 7),
  lastReadAt: ago(d: 2),
  sources: const [byteHarbor, kodehjornet, adaRowan, junoVale, circuitLedger],
  kindCounts: const {ItemKind.article: 2, ItemKind.post: 3},
  languages: const ['en', 'da'],
  visualSeed: 41,
  whatsNew: [
    Claim(
      id: 'kt-c1',
      text: 'An independent benchmark measured a 31% faster first load.',
      sources: const [circuitLedger],
      reportedAt: ago(h: 7),
    ),
  ],
  disagreements: const [
    Disagreement(
      id: 'kt-d1',
      topic: 'Start-up time',
      sides: [
        DisagreementSide(value: '−52%', claim: 'The project’s release notes.', sources: [byteHarbor, adaRowan]),
        DisagreementSide(value: '−31%', claim: 'An independent benchmark on mid-range laptops.', sources: [circuitLedger]),
      ],
    ),
  ],
  timeline: [
    TimelineEvent(id: 'kt-t1', at: ago(d: 3), text: 'Release candidate published.', kind: ItemKind.post, sourceCount: 2),
    TimelineEvent(id: 'kt-t2', at: ago(d: 1), text: 'Version 5 released.', kind: ItemKind.article, sourceCount: 4),
    TimelineEvent(id: 'kt-t3', at: ago(h: 7), text: 'Independent benchmark.', kind: ItemKind.article, sourceCount: 1),
  ],
);

final microbes = Story(
  id: 'microbes',
  title: 'Deep-sea microbes break down plastic faster than expected',
  summary:
      'Researchers found a microbe community near a hydrothermal vent that degrades PET in weeks rather '
      'than years. The results are from the lab so far; field tests start next year.',
  topic: 'Science',
  updatedAt: ago(d: 1),
  lastReadAt: ago(h: 2),
  sources: const [fieldnoteScience, deepSeaNotes, gradientHour],
  kindCounts: const {ItemKind.article: 2, ItemKind.episode: 1},
  languages: const ['en'],
  visualSeed: 53,
  timeline: [
    TimelineEvent(id: 'm-t1', at: ago(d: 1, h: 4), text: 'Paper published.', kind: ItemKind.article, sourceCount: 2),
    TimelineEvent(id: 'm-t2', at: ago(d: 1), text: 'Lead author interviewed.', kind: ItemKind.episode, sourceCount: 1),
  ],
);

final selene = Story(
  id: 'selene-3',
  title: 'Lunar lander Selene-3 sends its first images',
  summary: 'The lander touched down near the Moon’s south pole and returned its first panorama.',
  topic: 'Space',
  updatedAt: ago(h: 8),
  sources: const [orbitalWeekly, rumfartIDag],
  kindCounts: const {ItemKind.article: 2},
  languages: const ['en', 'da'],
  visualSeed: 67,
);

final stories = [halcyon, kestrel, cellcycle, kiteToolkit, microbes, selene];

/// 200-character title, 40 sources, 30 new facts, 10 disagreements, 40 events.
final extremeStory = Story(
  id: 'extreme',
  title:
      'A very long headline that keeps going to test wrapping: open-weight model release, new benchmark '
      'records in fourteen languages, licence questions, quantised weights and a surprise hardware partner',
  summary: List.filled(
    4,
    'This summary is deliberately long so the card has to truncate it and the story page has to wrap it '
    'over many lines without breaking the layout.',
  ).join(' '),
  topic: 'AI research',
  updatedAt: ago(m: 5),
  lastReadAt: ago(d: 6),
  sources: manySources(40),
  kindCounts: const {
    ItemKind.article: 18,
    ItemKind.episode: 4,
    ItemKind.video: 6,
    ItemKind.post: 22,
    ItemKind.photo: 3,
    ItemKind.comic: 1,
  },
  languages: const ['en', 'da', 'ta'],
  visualSeed: 99,
  whatsNew: [
    for (var i = 0; i < 30; i++)
      Claim(
        id: 'x-c$i',
        text: 'New fact number ${i + 1}, phrased at length so that it wraps across at least two lines on a phone.',
        sources: manySources(i % 6 + 1),
        reportedAt: ago(h: i * 3),
      ),
  ],
  disagreements: [
    for (var i = 0; i < 10; i++)
      Disagreement(
        id: 'x-d$i',
        topic: 'Contested figure ${i + 1} with a long label to test wrapping',
        sides: [
          DisagreementSide(value: '${1000 + i * 37} units', claim: 'One reading of the numbers.', sources: manySources(5)),
          DisagreementSide(value: '${800 + i * 11} units', claim: 'Another reading of the numbers.', sources: manySources(2)),
          if (i.isEven)
            DisagreementSide(value: 'Not disclosed', claim: 'A third source says no figure was given.', sources: manySources(1)),
        ],
      ),
  ],
  timeline: [
    for (var i = 0; i < 40; i++)
      TimelineEvent(
        id: 'x-t$i',
        at: ago(d: 12, h: -i * 7),
        text: 'Event ${i + 1}: something happened, described in a sentence long enough to wrap.',
        kind: ItemKind.values[i % ItemKind.values.length],
        sourceCount: i % 9 + 1,
      ),
  ],
);

// ── Items ────────────────────────────────────────────────────────────────────

final articleItem = Item(
  id: 'i-article',
  source: circuitLedger,
  kind: ItemKind.article,
  publishedAt: ago(h: 3),
  title: 'Halcyon-2’s 8-bit weights run on a single workstation GPU',
  text: 'We tried the new quantised release on a mid-range card. Here is what fits, what is slow, and what breaks.',
);
final postItem = Item(
  id: 'i-post',
  source: adaRowan,
  kind: ItemKind.post,
  publishedAt: ago(h: 1),
  text:
      'Ran the Danish eval set against Halcyon-2 this morning. Long sentences are much better; idioms '
      'still trip it up. Notes in the thread.',
  linkTitle: 'Halcyon-2 per-language results',
);
final videoItem = Item(
  id: 'i-video',
  source: launchpadLens,
  kind: ItemKind.video,
  publishedAt: ago(h: 6),
  title: 'Kestrel’s third landing, from the drone ship camera',
  duration: const Duration(minutes: 12, seconds: 48),
);
final episodeItem = Item(
  id: 'i-episode',
  source: gradientHour,
  kind: ItemKind.episode,
  publishedAt: ago(d: 1),
  title: 'Ep. 112: What “open weights” actually means',
  text: 'Licences, usage caps and who gets to build on top.',
  duration: const Duration(minutes: 48),
);
final photoItem = Item(
  id: 'i-photo',
  source: miraHolt,
  kind: ItemKind.photo,
  publishedAt: ago(h: 9),
  text: 'Morning fog over the launch site.',
);
final comicItem = Item(
  id: 'i-comic',
  source: debugDuck,
  kind: ItemKind.comic,
  publishedAt: ago(d: 2),
  title: 'Debug Duck #214: The model is very confident',
);
final items = [articleItem, postItem, videoItem, episodeItem, photoItem, comicItem];

final emptyItems = [
  Item(id: 'e-article', source: circuitLedger, kind: ItemKind.article, publishedAt: ago(m: 3)),
  Item(id: 'e-post', source: junoVale, kind: ItemKind.post, publishedAt: ago(m: 8)),
  Item(id: 'e-video', source: launchpadLens, kind: ItemKind.video, publishedAt: ago(m: 30), hasThumbnail: false),
  Item(id: 'e-episode', source: gradientHour, kind: ItemKind.episode, publishedAt: ago(h: 1)),
];

final extremeItems = [
  Item(
    id: 'x-article',
    source: manySources(1).first,
    kind: ItemKind.article,
    publishedAt: ago(d: 30),
    title:
        'An article title that runs to two hundred characters to make sure the card truncates gracefully '
        'instead of pushing everything else off the bottom of the card on small phones and narrow panes',
    text: List.filled(6, 'A long excerpt that keeps going.').join(' '),
  ),
  Item(
    id: 'x-post',
    source: const Source(
      id: 'long-handle',
      name: 'Someone With A Remarkably Long Display Name',
      type: SourceType.mastodon,
      language: 'en',
      handle: '@someone.with.a.very.long.handle@a-long-instance-name.social.example',
    ),
    kind: ItemKind.post,
    publishedAt: ago(m: 2),
    text: List.filled(
      10,
      'An untitled post of five hundred characters,',
    ).join(' '),
  ),
  Item(
    id: 'x-video',
    source: launchpadLens,
    kind: ItemKind.video,
    publishedAt: ago(h: 2),
    title: 'A video whose thumbnail is missing, with a long title that wraps onto a second line',
    duration: const Duration(hours: 2, minutes: 14),
    hasThumbnail: false,
  ),
];

// ── Briefing ─────────────────────────────────────────────────────────────────

final briefing = Briefing(
  date: DateTime.now(),
  chapters: const [
    BriefingChapter(storyId: 'halcyon-2', title: 'Halcyon-2 tops multilingual benchmarks', duration: Duration(minutes: 2, seconds: 10), newFactCount: 2),
    BriefingChapter(storyId: 'kestrel', title: 'Kestrel lands at sea for the third time', duration: Duration(minutes: 1, seconds: 35), newFactCount: 1),
    BriefingChapter(storyId: 'cellcycle', title: 'Copenhagen start-up raises €40 million', duration: Duration(minutes: 1, seconds: 20)),
    BriefingChapter(storyId: 'kite-5', title: 'Kite 5 halves web start-up time', duration: Duration(minutes: 1, seconds: 45), newFactCount: 1),
    BriefingChapter(storyId: 'microbes', title: 'Microbes that eat plastic', duration: Duration(minutes: 1, seconds: 5)),
    BriefingChapter(storyId: 'selene-3', title: 'Selene-3’s first images', duration: Duration(seconds: 50)),
  ],
);

final extremeBriefing = Briefing(
  date: DateTime.now(),
  chapters: [
    for (var i = 0; i < 20; i++)
      BriefingChapter(
        storyId: 'x-$i',
        title: 'Chapter ${i + 1}: a story title long enough that it needs two lines in the chapter list',
        duration: Duration(seconds: 30 + i * 13),
        newFactCount: i % 4,
      ),
  ],
);

// ── Accounts and onboarding ──────────────────────────────────────────────────

const user = User(id: 'u-ada', displayName: 'Ada Rowan', email: 'ada@users.example', language: 'en');
const longUser = User(
  id: 'u-long',
  displayName: 'Someone With A Remarkably Long Display Name',
  email: 'someone.with.a.remarkably.long.address@a-long-subdomain.users.example',
  language: 'da',
);

const privacyContact = 'privacy@osms.example';
const allSignInProviders = SignInProvider.values;
const popupBlocked = 'Your browser blocked the Google window. Allow pop-ups for this site, then try again.';
const signedUpElsewhere =
    'You first signed in with GitHub using ada@users.example. Continue with GitHub, then add Google in '
    'Settings so either one works next time.';

const languages = [
  AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
  AppLanguage(code: 'da', nativeName: 'Dansk', englishName: 'Danish'),
  AppLanguage(code: 'ta', nativeName: 'தமிழ்', englishName: 'Tamil'),
];

const topics = [
  Topic(id: 'ai-research', name: 'AI research', description: 'Models, papers, open weights'),
  Topic(id: 'developer-tools', name: 'Developer tools', description: 'Languages, frameworks, releases'),
  Topic(id: 'science', name: 'Science', description: 'Biology, physics, materials'),
  Topic(id: 'space', name: 'Space', description: 'Launches, missions, astronomy'),
  Topic(id: 'startups', name: 'Startups and product', description: 'Funding, launches, product news'),
];

final manyTopics = [
  for (var i = 0; i < 30; i++)
    Topic(id: 'topic-$i', name: 'Topic ${i + 1} with a longer name', description: 'A description that might wrap'),
];

const suggestions = [
  SourceSuggestion(source: inferenceBrief, topicId: 'ai-research', kind: ItemKind.article, note: 'Weekly'),
  SourceSuggestion(source: circuitLedger, topicId: 'ai-research', kind: ItemKind.article, note: 'About 6 a day'),
  SourceSuggestion(source: gradientHour, topicId: 'ai-research', kind: ItemKind.episode, note: 'Weekly episodes'),
  SourceSuggestion(source: openWeightsTag, topicId: 'ai-research', kind: ItemKind.post),
  SourceSuggestion(source: modelTinkerers, topicId: 'ai-research', kind: ItemKind.post),
  SourceSuggestion(source: byteHarbor, topicId: 'developer-tools', kind: ItemKind.article),
  SourceSuggestion(source: kodehjornet, topicId: 'developer-tools', kind: ItemKind.post, note: 'In Danish'),
  SourceSuggestion(source: fieldnoteScience, topicId: 'science', kind: ItemKind.article),
  SourceSuggestion(source: deepSeaNotes, topicId: 'science', kind: ItemKind.article),
  SourceSuggestion(source: orbitalWeekly, topicId: 'space', kind: ItemKind.article),
  SourceSuggestion(source: launchpadLens, topicId: 'space', kind: ItemKind.video),
  SourceSuggestion(source: rumfartIDag, topicId: 'space', kind: ItemKind.article, note: 'In Danish'),
  SourceSuggestion(source: miraHolt, topicId: 'space', kind: ItemKind.photo),
  SourceSuggestion(source: nordiskStartup, topicId: 'startups', kind: ItemKind.article, note: 'In Danish'),
  SourceSuggestion(source: batteryWeek, topicId: 'startups', kind: ItemKind.article),
];

final manySuggestions = [
  for (final (i, s) in manySources(120).indexed)
    SourceSuggestion(source: s, topicId: 'topic-${i % 30}', kind: ItemKind.values[i % 4], note: 'About ${i % 9 + 1} a week'),
];

// ── Add source ───────────────────────────────────────────────────────────────

final foundSource = DiscoveredSource(
  source: labNotes,
  frequency: 'about 4 posts a week',
  latest: [
    Item(id: 'ln-1', source: labNotes, kind: ItemKind.article, publishedAt: ago(h: 4), title: 'Why ocean labs keep their samples in the dark'),
    Item(id: 'ln-2', source: labNotes, kind: ItemKind.article, publishedAt: ago(d: 1), title: 'A field guide to reading error bars'),
    Item(id: 'ln-3', source: labNotes, kind: ItemKind.article, publishedAt: ago(d: 3), title: 'Three tools that make lab notebooks searchable'),
  ],
);

List<DiscoveredSource> opmlSources(int n) {
  const folders = ['AI', 'Space', 'Dev', 'Science', 'Startups', 'Reading'];
  return [
    for (final (i, s) in manySources(n).indexed)
      DiscoveredSource(
        source: s,
        folder: folders[i % folders.length],
        alreadyFollowed: i % 14 == 3,
        unreachable: i % 21 == 5,
      ),
  ];
}
