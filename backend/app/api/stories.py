"""Stories: the reader's own (their sources pick them), and the demo's for signed-out
visitors (every seed source, read-only, no read state). A story outside the reader's
sources is a 404, never a peek (rule 7)."""

import re
import time
from collections import defaultdict, deque
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request, status
from fastapi.responses import FileResponse

from app.api.deps import Db, Kit, Reader
from app.db.models import Story
from app.schemas.ask import AskRequest, AskResponse
from app.schemas.decisions import DecisionsOut
from app.schemas.stories import StoriesOut, StoryOut
from app.services import ask, decisions, stories

router = APIRouter()

#: Asking is rate-limited: per reader signed in, per address for the demo. Over the limit
#: reads as unavailable in the app, like any other failure to answer.
ASK_LIMIT, DEMO_ASK_LIMIT, ASK_WINDOW_S = 12, 6, 600.0
_asked: dict[str, deque[float]] = defaultdict(deque)


def _within_limit(key: str, limit: int) -> bool:
    now = time.monotonic()
    recent = _asked[key]
    while recent and now - recent[0] > ASK_WINDOW_S:
        recent.popleft()
    if len(recent) >= limit:
        return False
    recent.append(now)
    return True


def _answer(db, kit, story: Story, question: str, followed: set[int]) -> AskResponse:
    try:
        return ask.answer(db, kit, story, question, followed=followed)
    except ask.AskUnavailable:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "The answer service is unavailable right now.")


def _visible_story(db: Db, story_id: int, source_ids: set[int]) -> Story:
    story = db.get(Story, story_id)
    if story is None or not stories.visible_to(db, story_id, source_ids):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such story.")
    return story


_VISUAL_NAME = re.compile(r"^[0-9a-f]{32}\.webp$")


@router.get("/visuals/{name}")
def visual(name: str, request: Request) -> FileResponse:
    """A story's illustration. Not personal: the name is unguessable, and long-cached."""
    root: Path = request.app.state.visuals_dir
    if not _VISUAL_NAME.match(name) or not (root / name).is_file():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such illustration.")
    return FileResponse(root / name, media_type="image/webp", headers={"Cache-Control": "public, max-age=31536000, immutable"})


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


@router.get("/stories/{story_id}/decisions")
def reader_story_decisions(story_id: int, reader: Reader, db: Db) -> DecisionsOut:
    """How OSMS decided: the agent runs behind a story the reader can see."""
    _visible_story(db, story_id, stories.reader_source_ids(db, reader.id))
    return DecisionsOut(decisions=decisions.story_decisions(db, story_id))


@router.get("/demo/stories/{story_id}/decisions")
def demo_story_decisions(story_id: int, db: Db) -> DecisionsOut:
    _visible_story(db, story_id, stories.demo_source_ids(db))
    return DecisionsOut(decisions=decisions.story_decisions(db, story_id))


@router.post("/stories/{story_id}/ask")
def ask_story(story_id: int, body: AskRequest, reader: Reader, db: Db, kit: Kit) -> AskResponse:
    """Nothing is stored or logged: not the question, not the answer, not who asked."""
    followed = stories.reader_source_ids(db, reader.id)
    story = _visible_story(db, story_id, followed)
    if not _within_limit(f"reader:{reader.id}", ASK_LIMIT):
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Too many questions; try again in a few minutes.")
    return _answer(db, kit, story, body.question, followed)


@router.post("/demo/stories/{story_id}/ask")
def ask_demo_story(story_id: int, body: AskRequest, request: Request, db: Db, kit: Kit) -> AskResponse:
    followed = stories.demo_source_ids(db)
    story = _visible_story(db, story_id, followed)
    address = request.client.host if request.client else "unknown"
    if not _within_limit(f"address:{address}", DEMO_ASK_LIMIT):
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Too many questions; try again in a few minutes.")
    return _answer(db, kit, story, body.question, followed)
