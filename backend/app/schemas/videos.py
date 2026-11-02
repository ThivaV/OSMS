"""Videos: watchable items from the reader's own followed sources, newest first.
OSMS plays no video in-app: each row links to the publisher's page (a link,
never the file) and to the story it joined, when clustering placed it in one."""

from datetime import datetime

from pydantic import BaseModel

from app.schemas.account import SourceOut


class VideoOut(BaseModel):
    id: str
    title: str
    excerpt: str
    published_at: datetime
    #: The feed's stated length, when it states one; omitted otherwise, never guessed.
    duration_s: int | None
    #: The publisher's page. Always present: a video without a link gets no row.
    link: str
    source: SourceOut
    story_id: str | None = None
    story_title: str | None = None


class VideosOut(BaseModel):
    videos: list[VideoOut]
