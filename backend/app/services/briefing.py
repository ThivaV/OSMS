"""The morning briefing: OSMS's podcast. The editor agent picks the stories, the writer
agent scripts them from their kept facts (every sentence cited; code drops the rest), the
speech models voice them, and every chapter is transcribed back and compared with its
script before anyone hears it: one that drifts is remade once, then left out. Nothing
unchecked reaches a reader.

A reader's briefing comes only from their own sources' stories (rule 7); the demo's from
the seed sources'. Each is a new row: briefings are never overwritten."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

import numpy as np
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.agent.kit import AgentKit
from app.agent.prompts import load
from app.db.models import Briefing, Claim, Item, Story, User
from app.services import stories as stories_service
from app.services.speech import CHAPTER_PAUSE_S, CHECK_SIMILARITY, RATE, Checker, Voice, silence, similarity, wav_bytes
from app.services.verifier import current_claims
from app.services.writer import latest_summary

MAX_CHAPTERS = 5
LANGUAGES = {"en": "English", "da": "Danish", "ta": "Tamil"}
# Spoken before the first chapter; no facts in it. Tamil says "OSMS" letter by letter in
# Tamil script, and its numbers in words: its voice reads no Latin letters.
_TAMIL_COUNT = {1: "ஒரு செய்தி", 2: "இரண்டு செய்திகள்", 3: "மூன்று செய்திகள்", 4: "நான்கு செய்திகள்", 5: "ஐந்து செய்திகள்"}
_INTROS = {
    "en": lambda n: f"Good morning. Here is your OSMS briefing: {n} {'story' if n == 1 else 'stories'}.",
    "da": lambda n: f"Godmorgen. Her er din OSMS-briefing: {n} {'historie' if n == 1 else 'historier'}.",
    "ta": lambda n: f"காலை வணக்கம். இதோ உங்கள் ஓ எஸ் எம் எஸ் செய்திச் சுருக்கம்: {_TAMIL_COUNT[n]}.",
}


class _Pick(BaseModel):
    model_config = ConfigDict(extra="ignore")

    story_id: int
    reason: str = Field(default="", max_length=300)


class EditorOut(BaseModel):
    model_config = ConfigDict(extra="ignore", title="briefing_picks")

    picks: list[_Pick] = Field(min_length=1, max_length=8)  # required: see writer.WriterOut


class _Sentence(BaseModel):
    model_config = ConfigDict(extra="ignore")

    text: str = Field(min_length=1, max_length=400)
    claim_ids: list[int] = Field(min_length=1, max_length=8)


class _Chapter(BaseModel):
    model_config = ConfigDict(extra="ignore")

    story_id: int
    title: str = Field(min_length=1, max_length=160)
    sentences: list[_Sentence] = Field(min_length=1, max_length=5)


class ScriptOut(BaseModel):
    model_config = ConfigDict(extra="ignore", title="briefing_script")

    chapters: list[_Chapter] = Field(min_length=1, max_length=MAX_CHAPTERS)


@dataclass
class Candidate:
    story: Story
    title: str
    facts: list[Claim]
    new_facts: list[Claim]
    source_count: int
    updated_at: datetime


def _aware(moment: datetime) -> datetime:
    return moment.replace(tzinfo=UTC) if moment.tzinfo is None else moment


def candidates(db: Session, source_ids: set[int], since: datetime | None) -> list[Candidate]:
    """The reader's stories that have kept facts, with what is new since `since`."""
    found = []
    for story_id in stories_service.visible_story_ids(db, source_ids):
        facts = [c for c in current_claims(db, story_id) if c.status == "kept"]
        if not facts:
            continue
        story = db.get(Story, story_id)
        summary = latest_summary(db, story_id)
        items = list(db.scalars(select(Item).where(Item.story_id == story_id, Item.status != "dropped")))
        found.append(
            Candidate(
                story=story,
                title=summary.title if summary else (items[0].title if items else "Untitled story"),
                facts=facts,
                new_facts=[c for c in facts if since is None or (c.kept_at and _aware(c.kept_at) > since)],
                source_count=len({i.source_id for i in items}),
                updated_at=max((_aware(i.published_at) for i in items), default=_aware(story.updated_at)),
            )
        )
    return found


def _by_importance(found: list[Candidate]) -> list[Candidate]:
    return sorted(found, key=lambda c: (len(c.new_facts), c.source_count, c.updated_at), reverse=True)


def pick(kit: AgentKit, found: list[Candidate]) -> list[Candidate]:
    """The editor's picks; plain ranking (new facts, sources, newest) when it can't run."""
    fallback = [c for c in _by_importance(found) if c.new_facts][:MAX_CHAPTERS]
    if not found or not kit.can("editor"):
        return fallback
    listed = "\n".join(
        f"id {c.story.id}. {c.title} | {c.source_count} sources | {len(c.new_facts)} new facts | {len(c.facts)} facts"
        for c in _by_importance(found)[:30]
    )
    prompt = load("editor")
    result = kit.runner.call_once(
        kit.spec("editor", prompt_version=prompt.version, max_steps=2, token_budget=8_000),
        system=prompt.text,
        user=f"<stories>\n{listed}\n</stories>",
        schema=EditorOut,
    )
    if result.status != "ok" or result.value is None:
        return fallback
    by_id = {c.story.id: c for c in found}
    picked: list[Candidate] = []
    for p in EditorOut.model_validate(result.value).picks:
        if p.story_id in by_id and by_id[p.story_id] not in picked:
            picked.append(by_id[p.story_id])
    return picked[:MAX_CHAPTERS] or fallback


def script(kit: AgentKit, picked: list[Candidate], language: str) -> tuple[list[dict], str, str] | None:
    """Chapters with only sentences that cite their own story's facts, the model and the
    prompt version; None when the writer couldn't run or nothing survived."""
    if not picked or not kit.can("writer"):
        return None
    blocks = []
    for c in picked:
        facts = "\n".join(
            f"id {f.id}. {f.statement} | source: {f.item.source.title} | reported {f.item.published_at:%Y-%m-%d}"
            for f in (c.new_facts or c.facts)
        )
        blocks.append(f'<story id="{c.story.id}" title="{c.title}">\n{facts}\n</story>')
    prompt = load("briefing")
    result = kit.runner.call_once(
        kit.spec("writer", prompt_version=prompt.version, max_steps=2, token_budget=16_000),
        system=prompt.text,
        user=f"Language: {LANGUAGES[language]}\n\n" + "\n\n".join(blocks),
        schema=ScriptOut,
    )
    if result.status != "ok" or result.value is None:
        return None
    by_id = {c.story.id: c for c in picked}
    chapters = []
    for chapter in ScriptOut.model_validate(result.value).chapters:
        candidate = by_id.pop(chapter.story_id, None)
        if candidate is None:
            continue
        known = {f.id for f in candidate.facts}
        sentences = [
            {"text": s.text.strip(), "claim_ids": ids}
            for s in chapter.sentences
            if (ids := [i for i in s.claim_ids if i in known])
        ]
        if sentences:
            chapters.append(
                {
                    "story_id": candidate.story.id,
                    "title": chapter.title.strip(),
                    "sentences": sentences,
                    "new_fact_count": len(candidate.new_facts),
                }
            )
    return (chapters, kit.served_by("writer", result), prompt.version) if chapters else None


def _checked(voice: Voice, checker: Checker, text: str, language: str) -> tuple[np.ndarray, dict] | None:
    """The spoken text, once its transcript matches; remade once; None if it drifts twice."""
    for attempt in range(2):
        audio = voice.speak(text, language, attempt=attempt)
        try:
            heard = checker.transcribe(wav_bytes(audio), language)
        except RuntimeError:
            return None  # Unchecked never goes out.
        score = similarity(text, heard)
        if score >= CHECK_SIMILARITY:
            return audio, {"by": checker.by, "similarity": round(score, 3), "attempts": attempt + 1}
    return None


def make(
    db: Session,
    kit: AgentKit,
    voice: Voice,
    checkers: list[Checker],
    *,
    user: User | None,
    out_dir: Path,
) -> Briefing | None:
    """Today's briefing for a reader, or the demo's (`user=None`); None when there is
    nothing new, no writer, no way to check the audio, or no chapter passed its check."""
    language = user.language if user and user.language in LANGUAGES else "en"
    checker = next((c for c in checkers if c.handles(language)), None)
    if checker is None:
        return None
    user_id = user.id if user else None
    previous = db.scalar(
        select(Briefing.created_at)
        .where(Briefing.user_id.is_(None) if user_id is None else Briefing.user_id == user_id, Briefing.language == language)
        .order_by(Briefing.created_at.desc())
        .limit(1)
    )
    source_ids = stories_service.reader_source_ids(db, user_id) if user_id else stories_service.demo_source_ids(db)
    written = script(kit, pick(kit, candidates(db, source_ids, _aware(previous) if previous else None)), language)
    if written is None:
        return None
    chapters, model, prompt_version = written

    kept: list[tuple[dict, np.ndarray]] = []
    for chapter in chapters:
        spoken = _checked(voice, checker, f"{chapter['title']}. " + " ".join(s["text"] for s in chapter["sentences"]), language)
        if spoken is not None:
            kept.append(({**chapter, "check": spoken[1]}, spoken[0]))
    if not kept:
        return None
    intro_text = _INTROS[language](len(kept))
    intro = _checked(voice, checker, intro_text, language)
    parts: list[np.ndarray] = [intro[0], silence(CHAPTER_PAUSE_S)] if intro else []
    out = []
    for chapter, audio in kept:
        start = sum(len(p) for p in parts)
        parts += [audio, silence(CHAPTER_PAUSE_S)]
        out.append({**chapter, "start_ms": start * 1000 // RATE, "duration_ms": len(audio) * 1000 // RATE})
    audio = np.concatenate(parts[:-1])
    out_dir.mkdir(parents=True, exist_ok=True)
    name = f"{uuid.uuid4().hex}.wav"
    (out_dir / name).write_bytes(wav_bytes(audio))

    briefing = Briefing(
        user_id=user_id,
        language=language,
        intro=intro_text if intro else "",
        chapters=out,
        audio_path=name,
        duration_ms=len(audio) * 1000 // RATE,
        model=model,
        prompt_version=prompt_version,
        created_at=datetime.now(UTC),
    )
    db.add(briefing)
    db.commit()
    return briefing


def latest(db: Session, user_id: str | None) -> Briefing | None:
    where = Briefing.user_id.is_(None) if user_id is None else Briefing.user_id == user_id
    return db.scalar(select(Briefing).where(where, Briefing.audio_path.is_not(None)).order_by(Briefing.id.desc()).limit(1))
