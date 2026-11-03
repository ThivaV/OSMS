"""The demo video, scene by scene: what Biscuit says, its caption, and what is on screen.

Biscuit's lines are spelled for the voice ("O S M S", "Sam three point one"); the captions
spell the same words for the eye. Each line fits its clip at about 2.2 words a second, and
the clips add up to just under three minutes.
"""

import math
from dataclasses import dataclass

FRAME_RATE = 24  # LTX-2.5 was trained at 24


def frames_for(seconds: float) -> int:
    """LTX frame counts are 8k + 1."""
    return 8 * math.ceil((seconds * FRAME_RATE - 1) / 8) + 1


@dataclass(frozen=True)
class Scene:
    key: str
    say: str  # what Biscuit says, spelled for the voice
    caption: str  # the same words, spelled for the eye
    seconds: float  # the clip's length; trailing silence is trimmed when the cut is assembled
    shot: str  # a card ("card:<name>") or a recording of the live demo ("app:<name>")
    layout: str  # "big": Biscuit beside a card; "pip": Biscuit in a corner over the app
    wave: bool = False  # Biscuit waves hello or goodbye
    seed: int = 7  # change one scene's seed to make its clip again with another take
    label: str = ""  # beside the app: what this shot shows
    points: tuple[str, ...] = ()

    @property
    def frames(self) -> int:
        return frames_for(self.seconds)


SCENES = [
    Scene(
        "problem",
        say="Hi, I'm Biscuit! Every morning, the same news reaches you ten times: tech sites, a Danish paper, "
        "a podcast, a research paper. What's new? Where do they disagree? Who said what? Ten tabs, one story.",
        caption="Hi, I'm Biscuit! Every morning, the same news reaches you ten times: tech sites, a Danish paper, "
        "a podcast, a research paper. What's new? Where do they disagree? Who said what? Ten tabs, one story.",
        seconds=17,
        shot="card:problem",
        layout="big",
        wave=True,
    ),
    Scene(
        "meet",
        say="Meet O S M S: One Story, Many Sources. It reads every source you follow, in any language, turns each "
        "event into one story, and traces every sentence back to its sources.",
        caption="Meet OSMS: One Story, Many Sources. It reads every source you follow, in any language, turns each "
        "event into one story, and traces every sentence back to its sources.",
        seconds=16,
        shot="app:today",
        layout="pip",
        label='Meet OSMS',
        points=('Every source you follow', 'Any language', 'One story per event'),
    ),
    Scene(
        "story",
        say="Here's one story from three sources. Every sentence names its sources, and a tap opens the original: "
        "O S M S links, it never copies. What's new shows only what changed since your last visit.",
        caption="Here's one story from three sources. Every sentence names its sources, and a tap opens the "
        "original: OSMS links, it never copies. What's new shows only what changed since your last visit.",
        seconds=16,
        shot="app:story",
        layout="pip",
        seed=11,  # seed 7 spoke a little low for Biscuit
        label='One story, three sources',
        points=('Every sentence cited', 'Links, never copies', "What's new since your last visit"),
    ),
    Scene(
        "sections",
        say="When sources disagree, both sides sit next to each other. Corrections land in a dated timeline, never "
        "quietly overwritten. And languages mix: a Danish quote stays Danish, with a labelled translation.",
        caption="When sources disagree, both sides sit next to each other. Corrections land in a dated timeline, "
        "never quietly overwritten. And languages mix: a Danish quote stays Danish, with a labelled translation.",
        seconds=15,
        shot="app:sections",
        layout="pip",
        label='Disagreements, corrections, languages',
        points=('Both sides, side by side', 'Corrections kept, dated', 'Quotes in their own language'),
    ),
    Scene(
        "decided",
        say="My favourite part: How O S M S decided. Every model call behind a story is on its page: which Meta "
        "model, what it changed, its tokens and latency. Nothing generated reaches you unchecked.",
        caption="My favourite part: How OSMS decided. Every model call behind a story is on its page: which Meta "
        "model, what it changed, its tokens and latency. Nothing generated reaches you unchecked.",
        seconds=16,
        shot="app:decided",
        layout="pip",
        label='How OSMS decided',
        points=('Every model call on the page', 'Which Meta model, what it changed', 'Tokens and latency'),
    ),
    Scene(
        "listen",
        say="Every morning, O S M S makes you a short podcast of your top stories. Each sentence cites a checked "
        "fact, and Muse Voice Transcribe listens back to every chapter before you hear it.",
        caption="Every morning, OSMS makes you a short podcast of your top stories. Each sentence cites a checked "
        "fact, and Muse Voice Transcribe listens back to every chapter before you hear it.",
        seconds=16,
        shot="app:listen",
        layout="pip",
        seed=11,  # seed 7 slurred "Muse Voice Transcribe"
        label='Your morning briefing',
        points=('Every sentence cites a checked fact', 'Voiced by SeamlessM4T v2', 'Heard back by Muse Voice Transcribe'),
    ),
    Scene(
        "ask",
        say="Curious? Ask the story. Answers come only from its checked facts, with sources. If the sources never "
        "said it, O S M S says so instead of guessing.",
        caption="Curious? Ask the story. Answers come only from its checked facts, with sources. If the sources "
        "never said it, OSMS says so instead of guessing.",
        seconds=13,
        shot="app:ask",
        layout="pip",
        label='Ask this story',
        points=('Answers only from checked facts', 'With their sources', 'Or: the sources never said it'),
    ),
    Scene(
        "yours",
        say="And it's your reader. Paste any site, feed or social handle: O S M S finds the feed and previews it "
        "before you follow. Save a story, and it's there on the web and your Mac.",
        caption="And it's your reader. Paste any site, feed or social handle: OSMS finds the feed and previews it "
        "before you follow. Save a story, and it's there on the web and your Mac.",
        seconds=17,
        shot="app:yours",
        layout="pip",
        label='Make it yours',
        points=('Paste a site, feed or handle', 'Preview before you follow', 'Saved on the web and the Mac'),
    ),
    Scene(
        "meta",
        say="Seven Meta models do the work. Muse Spark triages, checks facts and writes. Muse Spark Open decides "
        "which reports are one event. Muse Image illustrates, Sam three point one checks each picture, and "
        "Seamless M 4 T and M M S speak the briefing.",
        caption="Seven Meta models do the work. Muse Spark triages, checks facts and writes. Muse Spark Open decides "
        "which reports are one event. Muse Image illustrates, SAM 3.1 checks each picture, and SeamlessM4T and "
        "MMS-TTS speak the briefing.",
        seconds=20,
        shot="card:meta",
        layout="big",
    ),
    Scene(
        "architecture",
        say="Under the hood, a pipeline, not a chatbot. A safe fetcher feeds a Fast A P I worker that triages, "
        "clusters, checks and writes. One Flutter app serves web and Mac, and articles stay as links, never "
        "copies.",
        caption="Under the hood, a pipeline, not a chatbot. A safe fetcher feeds a FastAPI worker that triages, "
        "clusters, checks and writes. One Flutter app serves web and Mac, and articles stay as links, never "
        "copies.",
        seconds=18,
        shot="card:architecture",
        layout="big",
    ),
    Scene(
        "outro",
        say="O S M S is live today, and open source. Try the demo, no account needed. One story, many sources. "
        "Biscuit out!",
        caption="OSMS is live today, and open source. Try the demo, no account needed. One story, many sources. "
        "Biscuit out!",
        seconds=11,
        shot="card:outro",
        layout="big",
        wave=True,
    ),
]

BY_KEY = {s.key: s for s in SCENES}
