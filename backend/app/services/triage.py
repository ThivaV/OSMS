"""Triage: is an item inside rule 3, and is it noise? The triage agent (Muse Glimmer,
Day 7) will decide this for every item. Until then this word list stands in, and it
errs on the side of dropping: a missed tech story costs less than a political one shown.

Dropped items keep their reason and never reach clustering, claims or a reader."""

import re

# Rule 3: nothing political, nothing involving war (English and Danish). Whole words…
_POLITICAL = (  # noqa: SIM905  (a word list reads better as words)
    "election elections electoral parliament parliamentary politician politicians "
    "political politics war wars warfare military troops missile missiles invasion "
    "ceasefire senator senators referendum folketinget folketingsvalg kommunalvalg valget "
    "valgkamp politiker politikere politisk politiske politik krig krigen krige militær "
    "militære militæret soldater missil missiler"
).split()
# …and stems that take endings: names ("Trumps", "Bidens"), ministers and governments.
_POLITICAL_STEMS = (  # noqa: SIM905  (a word list reads better as words)
    "trump biden putin netanyahu zelensk nato ukrain gaza hamas israel minist regering "
    "statsminist"
).split()
# Noise: adverts, giveaways and deal posts.
_NOISE = (  # noqa: SIM905  (a word list reads better as words)
    "sponsored giveaway giveaways deal deals coupon coupons annonce sponsoreret "
    "konkurrence tilbud rabatkode"
).split()

_POLITICAL_RE = re.compile(
    r"\b(" + "|".join(map(re.escape, _POLITICAL)) + r")\b|\b((?:" + "|".join(map(re.escape, _POLITICAL_STEMS)) + r")\w*)",
    re.IGNORECASE,
)
_NOISE_RE = re.compile(r"\b(" + "|".join(map(re.escape, _NOISE)) + r")\b", re.IGNORECASE)


def prefilter(title: str, text: str) -> str | None:
    """The reason to drop the item, or None to keep it."""
    words = f"{title}\n{text}"
    if match := _POLITICAL_RE.search(words):
        return f"rule 3: political ({(match.group(1) or match.group(2)).lower()!r})"
    if match := _NOISE_RE.search(title):
        return f"noise: {match.group(1).lower()!r} in the headline"
    return None
