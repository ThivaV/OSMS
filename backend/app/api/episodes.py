"""Episodes: the reader's podcasts, newest first, from their own sources only.
A story outside the reader's sources is a 404 elsewhere; here its episodes
simply never appear (rule 7). History pages by opaque cursor; one show's
history by `source_id`."""

from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status

from app.api.deps import Db, Reader
from app.schemas.episodes import EpisodesOut
from app.services import episodes
from app.services.episodes import BadCursor

router = APIRouter()


def _page(fetch, limit: int, cursor: str | None, source_id: int | None) -> EpisodesOut:
    try:
        rows, next_cursor, shows = fetch(limit, cursor, source_id)
    except BadCursor as error:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(error))
    return EpisodesOut(episodes=rows, next_cursor=next_cursor, shows=shows)


@router.get("/episodes")
def reader_episodes(
    reader: Reader,
    db: Db,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    cursor: Annotated[str | None, Query()] = None,
    source_id: Annotated[int | None, Query(ge=1)] = None,
) -> EpisodesOut:
    return _page(lambda lim, cur, src: episodes.reader_episodes(db, reader.id, lim, cur, src), limit, cursor, source_id)


@router.get("/demo/episodes")
def demo_episodes(
    db: Db,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    cursor: Annotated[str | None, Query()] = None,
    source_id: Annotated[int | None, Query(ge=1)] = None,
) -> EpisodesOut:
    """Public: the demo account's episodes, for signed-out visitors and judges."""
    return _page(lambda lim, cur, src: episodes.demo_episodes(db, lim, cur, src), limit, cursor, source_id)
