"""What the app gets for an episode: our own excerpt, its audio link, its show, and
the story it joined. Audio stays a link, never the file: playback streams from
the publisher (rule: media stays where it is)."""

from datetime import datetime

from pydantic import BaseModel


class EpisodeShowOut(BaseModel):
    #: Wire ids are strings everywhere (see StoryOut).
    id: str
    title: str
    type: str
    language: str


class EpisodeOut(BaseModel):
    id: str
    title: str
    #: The feed's own excerpt, capped: a list row, not the episode.
    excerpt: str
    published_at: datetime | None
    #: Seconds, when the feed states a length.
    duration_s: int | None
    #: The enclosure to stream, when the feed gave a safe one.
    audio_url: str | None
    show: EpisodeShowOut
    #: The story it joined, when clustering placed it in one.
    story_id: str | None = None
    story_title: str | None = None


class EpisodesOut(BaseModel):
    episodes: list[EpisodeOut]
    #: Opaque cursor for the next page; null when history ends here.
    next_cursor: str | None = None
    #: Every in-scope show with episodes, alphabetical — stable while paging.
    shows: list[EpisodeShowOut] = []
