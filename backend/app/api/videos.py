"""Videos: the reader's watchable items, newest first, from their own sources only.
A video outside the reader's sources simply never appears (rule 7). Rows link
out: OSMS keeps the publisher's link, never the video."""

from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import Db, Reader
from app.schemas.videos import VideosOut
from app.services import videos

router = APIRouter()


@router.get("/videos")
def reader_videos(
    reader: Reader,
    db: Db,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> VideosOut:
    return VideosOut(videos=videos.reader_videos(db, reader.id, limit))


@router.get("/demo/videos")
def demo_videos(
    db: Db,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> VideosOut:
    """Public: the demo account's videos, for signed-out visitors and judges."""
    return VideosOut(videos=videos.demo_videos(db, limit))
