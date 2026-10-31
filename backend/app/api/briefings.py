"""The morning briefing: a reader's own (rule 7: only theirs, never anyone else's), and
the demo's for signed-out visitors. The audio is served by a signed, short-lived URL that
only the briefing's reader is given."""

import hashlib
import hmac
import time
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request, status
from fastapi.responses import FileResponse

from app.api.deps import Db, Reader
from app.db.models import Briefing, Claim
from app.schemas.briefings import BriefingChapterOut, BriefingOut
from app.schemas.stories import PointOut
from app.services import briefing as briefing_service
from app.services import stories

router = APIRouter()

AUDIO_URL_TTL_S = 12 * 3600


def _signature(key: bytes, briefing_id: int, expires: int) -> str:
    return hmac.new(key, f"{briefing_id}.{expires}".encode(), hashlib.sha256).hexdigest()


def _out(db: Db, request: Request, briefing: Briefing, followed: set[int]) -> BriefingOut:
    expires = int(time.time()) + AUDIO_URL_TTL_S
    signature = _signature(request.app.state.audio_key, briefing.id, expires)
    claims = {c.id: c for c in db.query(Claim).filter(Claim.story_id.in_([c["story_id"] for c in briefing.chapters]))}

    def sentence(s: dict) -> PointOut:
        seen = []
        for claim_id in s["claim_ids"]:
            if (claim := claims.get(claim_id)) and claim.item.source not in seen:
                seen.append(claim.item.source)
        return PointOut(text=s["text"], sources=[stories._source(source, followed) for source in seen])

    return BriefingOut(
        id=str(briefing.id),
        created_at=briefing.created_at,
        language=briefing.language,
        duration_ms=briefing.duration_ms,
        audio_url=str(request.url_for("briefing_audio", briefing_id=briefing.id).include_query_params(expires=expires, signature=signature)),
        chapters=[
            BriefingChapterOut(
                story_id=str(c["story_id"]),
                title=c["title"],
                start_ms=c["start_ms"],
                duration_ms=c["duration_ms"],
                new_fact_count=c.get("new_fact_count", 0),
                sentences=[sentence(s) for s in c["sentences"]],
                checked_by=c["check"]["by"],
            )
            for c in briefing.chapters
        ],
    )


@router.get("/briefings/latest")
def reader_briefing(request: Request, reader: Reader, db: Db) -> BriefingOut:
    briefing = briefing_service.latest(db, reader.id)
    if briefing is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No briefing yet.")
    return _out(db, request, briefing, stories.reader_source_ids(db, reader.id))


@router.get("/demo/briefing")
def demo_briefing(request: Request, db: Db) -> BriefingOut:
    """Public: the demo's latest briefing, from the seed sources' stories."""
    briefing = briefing_service.latest(db, None)
    if briefing is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No briefing yet.")
    return _out(db, request, briefing, stories.demo_source_ids(db))


@router.get("/briefings/{briefing_id}/audio", name="briefing_audio")
def briefing_audio(briefing_id: int, expires: int, signature: str, request: Request, db: Db) -> FileResponse:
    expected = _signature(request.app.state.audio_key, briefing_id, expires)
    briefing = db.get(Briefing, briefing_id)
    if expires < time.time() or not hmac.compare_digest(expected, signature) or briefing is None or not briefing.audio_path:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such briefing.")
    root: Path = request.app.state.briefings_dir.resolve()
    path = (root / briefing.audio_path).resolve()
    if root not in path.parents or not path.is_file():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such briefing.")
    return FileResponse(path, media_type="audio/wav")
