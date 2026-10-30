"""The names an item mentions (companies, products, places), for clustering: two items
join a story without the judge only when they share one. Until the triage agent lists
names (Day 7), this heuristic does: words written like names, never ordinary words.

Kept lowercase, so "OpenAI" in a Danish and an English headline match."""

import re

_TOKEN = re.compile(r"[A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9.+\-]*[A-Za-zÀ-ÿ0-9+]|[A-Za-zÀ-ÿ0-9]")
_SENTENCE_END = re.compile(r"[.!?:]\s*$")

# Capitalised for grammar, not because they name anything (English and Danish).
_NOT_NAMES = frozenset(
    (  # noqa: SIM905  (a word list reads better as words)
        "a an the this that these those it its in on at for with by from of to and or but how "
        "why what when where who which new here today now report update review exclusive "
        "breaking video watch deal deals best first last more most top big next week weeks "
        "day year years i we you they he she our your their my his her is are was were be "
        "will can could should would may might must not no yes all every some any one two "
        "three monday tuesday wednesday thursday friday saturday sunday january february "
        "march april may june july august september october november december ai app apps "
        "update news tech science space study research researchers scientists den det de der "
        "en et ny nye se her nu når hvordan hvorfor hvad hvem hvilke test anmeldelse tilbud "
        "og eller men til fra med som af om på efter før under ifølge mandag tirsdag onsdag "
        "torsdag fredag lørdag søndag januar februar marts april maj juni juli august "
        "september oktober november december forskere forskning ny undersøgelse mah gb tb mb "
        "kb ghz mhz hz kwh mm cm km kg kr dkk usd eur gbp fps hdr usb"
    ).split()
)


def _looks_like_a_name(token: str, sentence_start: bool) -> bool:
    lower = token.lower()
    if lower in _NOT_NAMES or len(token) < 2:
        return False
    if any(ch.isdigit() for ch in token) and any(ch.isalpha() for ch in token):
        return True  # M4, S26, GPT-5, A19
    if token.isupper() and 2 <= len(token) <= 6:
        return True  # NASA, ESA, NVIDIA
    if any(ch.isupper() for ch in token[1:]):
        return True  # iPhone, OpenAI, YouTube
    return token[0].isupper() and not sentence_start


def names(title: str, text: str = "", *, limit: int = 20) -> list[str]:
    """Lowercase names from the title and the start of the text, in order, unique."""
    found: list[str] = []
    words = re.findall(r"[^\W\d_]+", title)
    # A Title Cased Headline capitalises ordinary words too ("With", "New"): then only
    # its strong names count. Sentence case ("Samsung præsenterer Galaxy S26") is trusted.
    title_cased = any(w[0].isupper() and w.lower() in _NOT_NAMES for w in words[1:]) or (
        len(words) >= 5 and all(w[0].isupper() for w in words)
    )
    for part, strong_only in ((title, title_cased), (text[:600], False)):
        tokens = [(m.group(), m.start()) for m in _TOKEN.finditer(part)]
        for n, (token, offset) in enumerate(tokens):
            start = n == 0 or bool(_SENTENCE_END.search(part[:offset]))
            if strong_only:
                is_name = _looks_like_a_name(token, sentence_start=True)
            else:
                is_name = _looks_like_a_name(token, sentence_start=start)
                # "Lumen Fold kommer…": a sentence starting with a two-word name.
                if not is_name and start and n + 1 < len(tokens):
                    following = tokens[n + 1][0]
                    is_name = token[:1].isupper() and token.lower() not in _NOT_NAMES and following[:1].isupper() and following.lower() not in _NOT_NAMES
            if is_name and (lower := token.lower()) not in found:
                found.append(lower)
                if len(found) >= limit:
                    return found
    return found
