"""Research interests on arXiv. Each interest becomes one arXiv search (quoted phrases in
titles and abstracts, its categories if any, newest first), stored as a shared source by
its URL and fetched daily: a reader's words are never in its title, and a shared query
never tells one reader that another follows the same words (rule 7). Every new paper,
from a search or a category feed, is matched against readers' interests by the words it
uses; each match records which, so a paper always says why it is there.

Not yet: related by meaning (BGE-M3 over papers; the threshold is the author's) and the
interest agent's suggestions."""

import re
from datetime import UTC, datetime, timedelta
from urllib.parse import urlencode

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Interest, InterestMatch, Item, Source, User

ARXIV_API = "https://export.arxiv.org/api/query"
MAX_RESULTS = 100  # newest first: the first fetch is the backfill
RESEARCH_DAYS = 14
_ABS_ID = re.compile(r"arxiv\.org/abs/([\w.\-/]+?)(?:v(\d+))?$")


def _phrase(term: str) -> str:
    term = term.replace('"', "").strip()
    return f'"{term}"' if " " in term else term


def query_url(keywords: list[str], related_terms: list[str], categories: list[str]) -> str:
    """The same words give the same URL, whatever their order or case (arXiv's search
    ignores case), so readers with the same words share one search."""
    terms = sorted({t.strip().casefold() for t in [*keywords, *related_terms] if t.strip()})
    words = " OR ".join(f"ti:{_phrase(t)} OR abs:{_phrase(t)}" for t in terms)
    query = f"({words})"
    if categories:
        query += " AND (" + " OR ".join(f"cat:{c}" for c in sorted(set(categories))) + ")"
    return f"{ARXIV_API}?" + urlencode(
        {"search_query": query, "sortBy": "submittedDate", "sortOrder": "descending", "max_results": MAX_RESULTS}
    )


def sync_sources(db: Session, user: User) -> None:
    """Point each of the reader's interests at its search, creating the shared source once."""
    for interest in user.interests:
        interest.query_url = query_url(interest.keywords, interest.related_terms, interest.categories)
        if db.scalar(select(Source.id).where(Source.feed_url == interest.query_url)) is None:
            db.add(Source(type="arxiv-query", title="arXiv search", feed_url=interest.query_url, html_url="https://arxiv.org"))
    db.flush()


def sync_all(db: Session) -> int:
    """Interests saved before they had a search get one (run at worker start)."""
    users = list(db.scalars(select(User).where(User.interests.any(Interest.query_url.is_(None)))))
    for user in users:
        sync_sources(db, user)
    db.commit()
    return len(users)


def _mentions(text: str, term: str) -> bool:
    return re.search(rf"(?<![\w-]){re.escape(term.strip())}(?![\w-])", text, re.IGNORECASE) is not None


def _feed_category(source: Source) -> str | None:
    """A category feed's category: https://rss.arxiv.org/rss/cs.CL is cs.CL."""
    if source.type != "arxiv" or not source.feed_url:
        return None
    return source.feed_url.rstrip("/").rsplit("/", 1)[-1]


def match_paper(db: Session, item: Item) -> int:
    """Record every interest the paper's title or abstract speaks to. An interest with
    categories only takes papers from its own search or from those categories' feeds.
    Returns how many matched."""
    if item.kind != "paper":
        return 0
    text = f"{item.title}\n{item.text}"
    category = _feed_category(item.source)
    found = 0
    for interest in db.scalars(select(Interest)):
        if interest.categories and item.source.feed_url != interest.query_url and category not in interest.categories:
            continue
        terms = [t for t in [*interest.keywords, *interest.related_terms] if _mentions(text, t)]
        if not terms:
            continue
        if db.scalar(select(InterestMatch.id).where(InterestMatch.interest_id == interest.id, InterestMatch.item_id == item.id)):
            continue
        db.add(InterestMatch(user_id=interest.user_id, interest_id=interest.id, item_id=item.id, matched_terms=terms))
        found += 1
    return found


def paper_id(link: str | None) -> tuple[str | None, int | None]:
    match = _ABS_ID.search(link or "")
    if not match:
        return None, None
    return match.group(1), int(match.group(2)) if match.group(2) else None


def research_for(db: Session, user_id: str, *, now: datetime | None = None) -> list[tuple[Item, list[str]]]:
    """The reader's matched papers from the last two weeks, newest first, each with the
    words it matched (across their interests)."""
    since = (now or datetime.now(UTC)) - timedelta(days=RESEARCH_DAYS)
    by_item: dict[int, tuple[Item, list[str]]] = {}
    for match in db.scalars(
        select(InterestMatch)
        .join(Item, Item.id == InterestMatch.item_id)
        .where(InterestMatch.user_id == user_id, Item.status != "dropped", InterestMatch.created_at >= since)
        .order_by(Item.published_at.desc())
        .limit(200)
    ):
        _, terms = by_item.setdefault(match.item_id, (match.item, []))
        terms.extend(t for t in match.matched_terms if t not in terms)
    return list(by_item.values())[:50]
