"""Videos: the reader's watchable items, newest first, from their own sources only
(rule 7). The demo's are the seed's, public like its stories. Rows link out:
OSMS keeps the publisher's link and the story it joined, never the video."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Item, StorySummary
from app.schemas.videos import VideoOut

#: The feed's own excerpt, capped: a list row, not the video.
EXCERPT_CHARS = 280

#: Videos per response unless asked for fewer.
MAX_VIDEOS = 100


def _describe(db: Session, source_ids: set[int], limit: int) -> list[VideoOut]:
    from app.services import stories

    if not source_ids:
        return []
    page_size = min(max(limit, 1), MAX_VIDEOS)
    items = list(
        db.scalars(
            select(Item)
            .where(
                Item.source_id.in_(source_ids),
                Item.kind == "video",
                Item.status != "dropped",
                Item.link.is_not(None),
            )
            .order_by(Item.published_at.desc(), Item.id.desc())
            .limit(page_size)
        )
    )
    # The latest summary names each story (ascending, so the newest row wins
    # each id); a story still waiting for its summary links by id alone.
    titles = dict(
        db.execute(
            select(StorySummary.story_id, StorySummary.title)
            .where(StorySummary.story_id.in_({item.story_id for item in items if item.story_id is not None}))
            .order_by(StorySummary.id)
        ).all()
    )
    return [
        VideoOut(
            id=str(item.id),
            title=item.title,
            excerpt=item.text[:EXCERPT_CHARS],
            published_at=item.published_at,
            duration_s=item.duration_s,
            link=item.link,
            source=stories._source(item.source, source_ids),
            story_id=str(item.story_id) if item.story_id is not None else None,
            story_title=titles.get(item.story_id) if item.story_id is not None else None,
        )
        for item in items
    ]


def reader_videos(db: Session, user_id: str, limit: int) -> list[VideoOut]:
    from app.services.stories import reader_source_ids

    return _describe(db, reader_source_ids(db, user_id), limit)


def demo_videos(db: Session, limit: int) -> list[VideoOut]:
    from app.services.stories import demo_source_ids

    return _describe(db, demo_source_ids(db), limit)
