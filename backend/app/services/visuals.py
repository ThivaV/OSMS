"""Story illustrations with Muse Image, in one house style (OSMS's threads braiding into
one bright story thread, on paper), with a motif from OSMS's own summary title, never
from source text. SAM 3.1 checks each one for people, faces, logos and text before
anyone sees it: a flagged one is redrawn once without the motif, then the card keeps
its drawn art. SAM also finds the bright thread, so cards crop around it. Every
illustration is labelled as one in the app."""

import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Protocol

from sqlalchemy.orm import Session

from app.agent.decision_log import DecisionLog
from app.db.models import Story
from app.services.writer import latest_summary

#: A story is illustrated once it has this many sources (AGENTS.md: three, tunable).
ILLUSTRATE_AT_SOURCES = 3
#: What must not be in an illustration (SAM takes one noun phrase per request).
FLAGS = ("a person", "a face", "a logo", "text")
#: How sure SAM must be before a find counts. Provisional, like every threshold: yours.
FLAG_CONFIDENCE = 0.5
FOCUS_PHRASES = ("yellow braid", "yellow line")

STYLE = (
    "A flat, abstract editorial illustration on warm paper texture, muted palette: thin coloured threads "
    "flow in from the edges and braid into one bright yellow thread."
)
NEVER = (
    "No people, no faces, no hands, no logos, no brand marks, no real products, no photographs, "
    "no text, letters or numbers."
)


class Media(Protocol):
    image_model: str
    sam_model: str

    def draw(self, prompt: str) -> bytes: ...

    def find(self, image: bytes, phrase: str) -> list: ...


def prompt_for(title: str | None) -> str:
    if not title:
        return f"{STYLE} {NEVER}"
    motif = title.replace('"', "").strip()[:160]
    return (
        f"{STYLE} Around where they meet, a few simple geometric shapes suggest the idea of "
        f'"{motif}", never a real product, place or company. {NEVER}'
    )


def _flagged(media: Media, image: bytes) -> str | None:
    for phrase in FLAGS:
        if any(box.confidence >= FLAG_CONFIDENCE for box in media.find(image, phrase)):
            return phrase
    return None


def illustrate(db: Session, media: Media, story: Story, out_dir: Path, log: DecisionLog | None = None) -> dict:
    """Draw, check and store the story's illustration; records the outcome on the story
    either way, so it is tried once, and in the decision log ("How OSMS decided").
    Returns that record."""
    run_id = log.start_run(agent="illustration", model=media.image_model, subject=f"story:{story.id}") if log else None
    summary = latest_summary(db, story.id)
    record: dict = {"model": media.image_model, "checked_by": media.sam_model, "attempts": 0, "at": datetime.now(UTC).isoformat()}
    image = None
    for prompt in (prompt_for(summary.title if summary else None), prompt_for(None)):
        record["attempts"] += 1
        drawn = media.draw(prompt)
        if (flag := _flagged(media, drawn)) is None:
            image = drawn
            break
        record.setdefault("flagged", []).append(flag)
    if image is None:
        record["status"] = "drawn art"  # Flagged twice: the card keeps StoryVisual.
    else:
        focus = (0.5, 0.5)
        for phrase in FOCUS_PHRASES:
            if boxes := media.find(image, phrase):
                focus = max(boxes, key=lambda b: b.confidence).centre
                break
        out_dir.mkdir(parents=True, exist_ok=True)
        name = f"{uuid.uuid4().hex}.webp"
        (out_dir / name).write_bytes(image)
        record |= {"status": "ready", "path": name, "focus": [round(focus[0], 3), round(focus[1], 3)]}
    if log and run_id is not None:
        flags = record.get("flagged", [])
        log.log_step(
            run_id=run_id,
            position=0,
            model=media.sam_model,
            reason=(f"SAM 3.1 found {' then '.join(flags)}" if flags else "SAM 3.1 found no people, faces, logos or text")
            + ("; redrawn without the motif" if len(flags) == 1 and image is not None else ""),
        )
        log.end_run(run_id=run_id, status="ok")
    story.illustration = record
    db.commit()
    return record
