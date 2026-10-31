"""The morning briefing on the wire: one audio file, chapters by offset, each sentence
with the sources behind its facts."""

from datetime import datetime

from pydantic import BaseModel

from app.schemas.stories import PointOut


class BriefingChapterOut(BaseModel):
    story_id: str
    title: str
    start_ms: int
    duration_ms: int
    new_fact_count: int
    sentences: list[PointOut]
    #: The model that transcribed the chapter back to check it.
    checked_by: str


class BriefingOut(BaseModel):
    id: str
    created_at: datetime
    language: str
    duration_ms: int
    #: Signed and short-lived: audio players can't send a sign-in header.
    audio_url: str
    chapters: list[BriefingChapterOut]
