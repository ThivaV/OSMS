"""Episodes: a reader's podcasts, newest first, from their own sources only
(rule 7). The demo's are the seed's, public like its stories.

History paging is cursor (keyset) based on the `(published_at, id)` composite:
a page continues exactly where the last one ended, so episodes fetched while
browsing neither duplicate nor skip rows. The cursor is opaque to callers.
"""

import base64
import binascii
import json
from datetime import UTC, datetime

from sqlalchemy import select, tuple_
from sqlalchemy.orm import Session

from app.db.models import Item, Source, StorySummary
from app.schemas.episodes import EpisodeOut, EpisodeShowOut

#: A list row, not the episode: the feed's excerpt, capped.
EXCERPT_CHARS = 280

#: Episodes per response unless asked for fewer.
MAX_EPISODES = 100


class BadCursor(ValueError):
    """The cursor isn't one of ours. The API answers 422: fix the caller."""


def encode_cursor(published_at: datetime, item_id: int) -> str:
    at = published_at if published_at.tzinfo is not None else published_at.replace(tzinfo=UTC)
    raw = json.dumps({"published_at": at.isoformat(), "id": item_id}, separators=(",", ":"))
    return base64.urlsafe_b64encode(raw.encode()).decode()


def decode_cursor(cursor: str) -> tuple[datetime, int]:
    try:
        document = json.loads(base64.urlsafe_b64decode(cursor.encode()))
        at = datetime.fromisoformat(document["published_at"])
        item_id = int(document["id"])
    except (binascii.Error, ValueError, KeyError, TypeError, AttributeError) as error:
        raise BadCursor(f"not an episodes cursor: {cursor[:32]!r}") from error
    if at.tzinfo is None:
        at = at.replace(tzinfo=UTC)
    return at, item_id


def _page(
    db: Session, source_ids: set[int], limit: int, cursor: str | None, source_id: int | None
) -> tuple[list[Item], str | None]:
    statement = (
        select(Item)
        .where(Item.source_id.in_(source_ids), Item.kind == "episode", Item.status != "dropped")
        .order_by(Item.published_at.desc(), Item.id.desc())
    )
    if source_id is not None:
        statement = statement.where(Item.source_id == source_id)
    if cursor is not None:
        at, item_id = decode_cursor(cursor)
        statement = statement.where(tuple_(Item.published_at, Item.id) < (at, item_id))
    page_size = min(max(limit, 1), MAX_EPISODES)
    rows = list(db.scalars(statement.limit(page_size + 1)))
    if len(rows) <= page_size:
        return rows, None
    rows.pop()  # lookahead only: it proves history continues, it names no cursor
    last = rows[-1]
    return rows, encode_cursor(last.published_at, last.id)


def _shows(db: Session, source_ids: set[int]) -> list[EpisodeShowOut]:
    """Every in-scope show with episodes, alphabetical. Independent of paging
    and of any active filter, so the chips never shift under the reader."""
    if not source_ids:
        return []
    with_episodes = (
        select(Item.source_id)
        .where(Item.source_id.in_(source_ids), Item.kind == "episode", Item.status != "dropped")
        .distinct()
    )
    sources = db.scalars(select(Source).where(Source.id.in_(with_episodes)).order_by(Source.title)).all()
    return [
        EpisodeShowOut(id=str(source.id), title=source.title, type=source.type, language=source.language)
        for source in sources
    ]


def _describe(
    db: Session, source_ids: set[int], limit: int, cursor: str | None, source_id: int | None
) -> tuple[list[EpisodeOut], str | None, list[EpisodeShowOut]]:
    if not source_ids:
        return [], None, []
    items, next_cursor = _page(db, source_ids, limit, cursor, source_id)
    # The latest summary names each story (ascending, so the newest row wins
    # each id); a story still waiting for its summary links by id alone, and
    # the app shows no title for it.
    titles = dict(
        db.execute(
            select(StorySummary.story_id, StorySummary.title)
            .where(StorySummary.story_id.in_({item.story_id for item in items if item.story_id is not None}))
            .order_by(StorySummary.id)
        ).all()
    )
    return (
        [
            EpisodeOut(
                id=str(item.id),
                title=item.title,
                excerpt=item.text[:EXCERPT_CHARS],
                published_at=item.published_at,
                duration_s=item.duration_s,
                audio_url=item.audio_url,
                show=EpisodeShowOut(
                    id=str(item.source.id),
                    title=item.source.title,
                    type=item.source.type,
                    language=item.source.language,
                ),
                story_id=str(item.story_id) if item.story_id is not None else None,
                story_title=titles.get(item.story_id) if item.story_id is not None else None,
            )
            for item in items
        ],
        next_cursor,
        _shows(db, source_ids),
    )


def reader_episodes(
    db: Session, user_id: str, limit: int, cursor: str | None = None, source_id: int | None = None
) -> tuple[list[EpisodeOut], str | None, list[EpisodeShowOut]]:
    from app.services.stories import reader_source_ids

    return _describe(db, reader_source_ids(db, user_id), limit, cursor, source_id)


def demo_episodes(
    db: Session, limit: int, cursor: str | None = None, source_id: int | None = None
) -> tuple[list[EpisodeOut], str | None, list[EpisodeShowOut]]:
    from app.services.stories import demo_source_ids

    return _describe(db, demo_source_ids(db), limit, cursor, source_id)
