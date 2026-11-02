"""Episodes: a reader's podcasts, newest first, from their own sources only
(rule 7). The demo's are the seed's, public like its stories."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Item, StorySummary
from app.schemas.episodes import EpisodeOut, EpisodeShowOut

#: A list row, not the episode: the feed's excerpt, capped.
EXCERPT_CHARS = 280

#: Episodes per response unless asked for fewer.
MAX_EPISODES = 100


def _episodes(db: Session, source_ids: set[int], limit: int) -> list[EpisodeOut]:
    if not source_ids:
        return []
    items = list(
        db.scalars(
            select(Item)
            .where(Item.source_id.in_(source_ids), Item.kind == "episode", Item.status != "dropped")
            .order_by(Item.published_at.desc(), Item.id.desc())
            .limit(min(max(limit, 1), MAX_EPISODES))
        )
    )
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
    return [
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
    ]


def reader_episodes(db: Session, user_id: str, limit: int) -> list[EpisodeOut]:
    from app.services.stories import reader_source_ids

    return _episodes(db, reader_source_ids(db, user_id), limit)


def demo_episodes(db: Session, limit: int) -> list[EpisodeOut]:
    from app.services.stories import demo_source_ids

    return _episodes(db, demo_source_ids(db), limit)
