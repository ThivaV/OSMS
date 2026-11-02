"""Episodes: the reader's podcasts, newest first, from their own sources only.
A story outside the reader's sources is a 404 elsewhere; here its episodes
simply never appear (rule 7)."""

from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import Db, Reader
from app.schemas.episodes import EpisodesOut
from app.services import episodes

router = APIRouter()


@router.get("/episodes")
def reader_episodes(reader: Reader, db: Db, limit: Annotated[int, Query(ge=1, le=100)] = 50) -> EpisodesOut:
    return EpisodesOut(episodes=episodes.reader_episodes(db, reader.id, limit))


@router.get("/demo/episodes")
def demo_episodes(db: Db, limit: Annotated[int, Query(ge=1, le=100)] = 50) -> EpisodesOut:
    """Public: the demo account's episodes, for signed-out visitors and judges."""
    return EpisodesOut(episodes=episodes.demo_episodes(db, limit))
