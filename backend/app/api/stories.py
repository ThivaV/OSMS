"""Stories: the reader's own (their sources pick them), and the demo's for signed-out
visitors (every seed source, read-only, no read state). A story outside the reader's
sources is a 404, never a peek (rule 7)."""

from fastapi import APIRouter, HTTPException, status

from app.api.deps import Db, Reader
from app.db.models import Story
from app.schemas.stories import StoriesOut, StoryOut
from app.services import stories

router = APIRouter()


def _visible_story(db: Db, story_id: int, source_ids: set[int]) -> Story:
    story = db.get(Story, story_id)
    if story is None or not stories.visible_to(db, story_id, source_ids):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such story.")
    return story


@router.get("/stories")
def reader_stories(reader: Reader, db: Db) -> StoriesOut:
    return StoriesOut(stories=stories.reader_stories(db, reader.id))


@router.get("/stories/{story_id}")
def reader_story(story_id: int, reader: Reader, db: Db) -> StoryOut:
    followed = stories.reader_source_ids(db, reader.id)
    story = _visible_story(db, story_id, followed)
    from app.db.models import ReadState

    state = db.get(ReadState, (reader.id, story_id))
    return stories.story_out(db, story, followed=followed, read_at=state.read_at if state else None)


@router.post("/stories/{story_id}/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_read(story_id: int, reader: Reader, db: Db) -> None:
    _visible_story(db, story_id, stories.reader_source_ids(db, reader.id))
    stories.mark_read(db, reader.id, story_id)


@router.get("/demo/stories")
def demo_stories(db: Db) -> StoriesOut:
    """Public: the demo account's stories, for signed-out visitors and judges."""
    return StoriesOut(stories=stories.demo_stories(db))


@router.get("/demo/stories/{story_id}")
def demo_story(story_id: int, db: Db) -> StoryOut:
    followed = stories.demo_source_ids(db)
    return stories.story_out(db, _visible_story(db, story_id, followed), followed=followed, read_at=None)
