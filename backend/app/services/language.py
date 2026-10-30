"""Which language an item is in: Tamil by its script, Danish or English by their most
common words. The feed's own language is the answer when the text is too short to tell."""

import re

_WORD = re.compile(r"[a-zæøåéü]+")

# Words common in one language and rare in the other ("for", "over", "at" are in both).
_DANISH = frozenset(
    (  # noqa: SIM905  (a word list reads better as words)
        "og det er en til på med den som af ikke de har jeg vi kan der et om var så nu skal "
        "hvis også efter ved fra blev bliver når være hvor eller nye mere kun mod sin sine "
        "deres meget får fik siger sagde mellem både første andre hele kommer"
    ).split()
)
_ENGLISH = frozenset(
    (  # noqa: SIM905  (a word list reads better as words)
        "the and of to in is it that on with as was are by be this from or an have has not "
        "but they their which will more can its than about into been would after says said "
        "between both first other whole comes"
    ).split()
)


def normalise(code: str | None) -> str | None:
    """`da-DK` → `da`; empty → None."""
    if not code:
        return None
    return code.strip().lower().replace("_", "-").split("-")[0] or None


def detect(text: str, hint: str | None = None) -> str:
    """`ta`, `da` or `en`, else the hint, else `en`."""
    if any("஀" <= ch <= "௿" for ch in text):
        return "ta"
    words = _WORD.findall(text.lower())
    danish = sum(word in _DANISH for word in words) + sum(text.count(ch) for ch in "æøåÆØÅ")
    english = sum(word in _ENGLISH for word in words)
    if danish + english < 3:
        return normalise(hint) or "en"
    return "da" if danish > english else "en"
