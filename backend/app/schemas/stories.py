"""What the app gets for a story: our own title and cited summary, what's new since the
reader last read it, where sources disagree, how it developed, and every source.

Third-party text appears only as headlines and as the short quotes facts rest on, each
linked to its source (rule 5). Summaries are always OSMS's own words."""

from datetime import datetime

from pydantic import BaseModel

from app.schemas.account import SourceOut


class StorySourceOut(SourceOut):
    followed: bool = False


class PointOut(BaseModel):
    text: str
    sources: list[StorySourceOut]


class ClaimOut(BaseModel):
    id: str
    text: str
    sources: list[StorySourceOut]
    reported_at: datetime
    #: The words it rests on, in the source's language, and their English translation
    #: when the source wrote in another language ("Translated by OSMS").
    quote: str
    quote_language: str
    translation: str | None
    #: How many sources report it: 1 is "One source so far".
    source_count: int
    #: For a correction: what the source said before.
    corrects: str | None = None


class SideOut(BaseModel):
    value: str
    claim: str
    sources: list[StorySourceOut]


class DisagreementOut(BaseModel):
    id: str
    topic: str
    sides: list[SideOut]


class TimelineEventOut(BaseModel):
    id: str
    at: datetime
    text: str
    kind: str
    source_count: int
    #: The original article, for a report; null for OSMS's own events.
    url: str | None = None
    #: For a correction: the value the source replaced, shown struck through.
    corrected_from: str | None = None


class StoryOut(BaseModel):
    id: str
    title: str
    summary: str
    summary_points: list[PointOut]
    topic: str
    updated_at: datetime
    sources: list[StorySourceOut]
    kind_counts: dict[str, int]
    languages: list[str]
    visual_seed: int
    has_illustration: bool = False
    last_read_at: datetime | None
    whats_new: list[ClaimOut]
    disagreements: list[DisagreementOut]
    timeline: list[TimelineEventOut]
    #: Why it is in the list, in words: "3 sources", "2 new facts", "AI research".
    why: list[str]


class StoriesOut(BaseModel):
    stories: list[StoryOut]
