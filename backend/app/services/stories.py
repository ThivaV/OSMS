"""Stories as a reader sees them. Your sources pick the stories; the story shows every
source (AGENTS.md, *Collecting what users pick*). What's new is what the verifier kept
after the reader last opened the story; corrections and the timeline come from the same
history, which is never overwritten."""

from collections import Counter
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import Claim, Disagreement, Item, ReadState, Source, Story, Subscription, Topic, TopicSource
from app.schemas.stories import (
    ClaimOut,
    DisagreementOut,
    PointOut,
    SideOut,
    StoryOut,
    StorySourceOut,
    TimelineEventOut,
)
from app.services.writer import latest_summary

MAX_STORIES = 100


def _aware(moment: datetime) -> datetime:
    return moment.replace(tzinfo=UTC) if moment.tzinfo is None else moment


def reader_source_ids(db: Session, user_id: str) -> set[int]:
    return set(db.scalars(select(Subscription.source_id).where(Subscription.user_id == user_id)))


def demo_source_ids(db: Session) -> set[int]:
    """The demo account follows every seed source."""
    return set(db.scalars(select(TopicSource.source_id)))


def visible_story_ids(db: Session, source_ids: set[int]) -> list[int]:
    """Stories with an item from these sources: those with two or more sources first,
    then by their newest item. The editor agent ranks per reader later (Day 7)."""
    if not source_ids:
        return []
    mine = select(Item.story_id).where(Item.source_id.in_(source_ids), Item.story_id.is_not(None), Item.status != "dropped")
    # An article two feeds both list (one publisher's sections) counts once: by its link.
    rows = db.execute(
        select(Item.story_id, func.count(func.distinct(func.coalesce(Item.link, Item.guid))), func.max(Item.published_at))
        .where(Item.story_id.in_(mine), Item.status != "dropped")
        .group_by(Item.story_id)
    ).all()
    rows.sort(key=lambda r: (r[1] > 1, _aware(r[2])), reverse=True)
    return [r[0] for r in rows[:MAX_STORIES]]


def _source(source: Source, followed: set[int]) -> StorySourceOut:
    return StorySourceOut(
        id=str(source.id),
        name=source.title,
        type=source.type,
        language=source.language,
        url=source.html_url,
        followed=source.id in followed,
    )


def _topics_by_source(db: Session, source_ids: set[int]) -> dict[int, str]:
    rows = db.execute(
        select(TopicSource.source_id, Topic.name).join(Topic, Topic.id == TopicSource.topic_id).where(
            TopicSource.source_id.in_(source_ids)
        )
    ).all()
    return {source_id: name for source_id, name in rows}


def story_out(db: Session, story: Story, *, followed: set[int], read_at: datetime | None) -> StoryOut:
    items: list[Item] = []
    links: set[str] = set()
    for i in db.scalars(select(Item).where(Item.story_id == story.id).order_by(Item.published_at, Item.id)):
        # One article listed by two of a publisher's feeds is one report, not two sources.
        if i.status == "dropped" or (i.link and i.link in links):
            continue
        links.add(i.link or "")
        items.append(i)
    sources: dict[int, Source] = {}
    for item in items:
        sources.setdefault(item.source_id, item.source)
    topics = _topics_by_source(db, set(sources))
    topic = Counter(topics[i.source_id] for i in items if i.source_id in topics).most_common(1)
    topic_name = topic[0][0] if topic else "News"

    claims = list(db.scalars(select(Claim).where(Claim.story_id == story.id).order_by(Claim.id)))
    by_id = {c.id: c for c in claims}
    shown = [c for c in claims if c.status == "kept"]
    # A repeat from another source corroborates the fact it repeats.
    backers: dict[int, list[Source]] = {c.id: [c.item.source] for c in shown}
    for c in claims:
        if c.status == "repeat" and c.related_claim_id in backers and c.item.source not in backers[c.related_claim_id]:
            backers[c.related_claim_id].append(c.item.source)

    def claim_out(c: Claim) -> ClaimOut:
        old = by_id.get(c.related_claim_id) if c.relation == "corrects" else None
        return ClaimOut(
            id=str(c.id),
            text=c.statement,
            sources=[_source(s, followed) for s in backers.get(c.id, [c.item.source])],
            reported_at=_aware(c.item.published_at),
            quote=c.quote,
            quote_language=c.quote_language,
            translation=c.translation,
            source_count=len(backers.get(c.id, [c.item.source])),
            corrects=(old.value or old.statement) if old else None,
        )

    since = _aware(read_at) if read_at else None
    whats_new = [
        claim_out(c)
        for c in shown
        if c.superseded_at is None and c.kept_at and (since is None or _aware(c.kept_at) > since)
    ]

    disagreements = []
    for d in db.scalars(select(Disagreement).where(Disagreement.story_id == story.id).order_by(Disagreement.id)):
        a, b = by_id.get(d.claim_a_id), by_id.get(d.claim_b_id)
        if a is None or b is None:
            continue
        disagreements.append(
            DisagreementOut(
                id=str(d.id),
                topic=d.subject or a.subject or "A reported fact",
                sides=[
                    SideOut(value=c.value or c.statement, claim=c.statement, sources=[_source(c.item.source, followed)])
                    for c in (a, b)
                ],
            )
        )

    timeline = [
        TimelineEventOut(
            id=f"item-{i.id}", at=_aware(i.published_at), text=i.title or i.text[:140], kind=i.kind, source_count=1, url=i.link
        )
        for i in items
    ]
    for c in claims:
        if c.relation == "corrects" and c.status == "kept" and (old := by_id.get(c.related_claim_id)):
            timeline.append(
                TimelineEventOut(
                    id=f"correction-{c.id}",
                    at=_aware(c.kept_at or c.created_at),
                    text=f"{c.item.source.title} corrected {c.subject or 'a fact'}: {c.value or c.statement}",
                    kind=c.item.kind,
                    source_count=1,
                    url=c.item.link,
                    corrected_from=old.value or old.statement,
                )
            )
    timeline.sort(key=lambda e: e.at)

    summary = latest_summary(db, story.id)
    points = []
    if summary:
        for p in summary.points:
            cited = [by_id[i] for i in p.get("claim_ids", []) if i in by_id]
            seen: list[Source] = []
            for c in cited:
                for s in backers.get(c.id, [c.item.source]):
                    if s not in seen:
                        seen.append(s)
            points.append(PointOut(text=p["text"], sources=[_source(s, followed) for s in seen]))
    languages = sorted({i.language for i in items})
    named = {"da": "Danish", "en": "English", "ta": "Tamil"}
    fallback = f"Reported by {len(sources)} source{'s' if len(sources) != 1 else ''}"
    if len(languages) > 1:
        fallback += " in " + " and ".join(named.get(l, l) for l in languages)
    title = summary.title if summary else (items[0].title if items else "Untitled story")
    why = [f"{len(sources)} source{'s' if len(sources) != 1 else ''}"]
    if whats_new:
        why.append(f"{len(whats_new)} new fact{'s' if len(whats_new) != 1 else ''}")
    why.append(topic_name)
    return StoryOut(
        id=str(story.id),
        title=title,
        summary=" ".join(p.text for p in points) if points else fallback + ".",
        summary_points=points,
        topic=topic_name,
        updated_at=max((_aware(i.published_at) for i in items), default=_aware(story.updated_at)),
        sources=[_source(s, followed) for s in sources.values()],
        kind_counts=dict(Counter(i.kind for i in items)),
        languages=languages,
        visual_seed=story.id,
        last_read_at=since,
        whats_new=whats_new,
        disagreements=disagreements,
        timeline=timeline,
        why=why,
    )


def reader_stories(db: Session, user_id: str) -> list[StoryOut]:
    followed = reader_source_ids(db, user_id)
    read = dict(db.execute(select(ReadState.story_id, ReadState.read_at).where(ReadState.user_id == user_id)).all())
    return [story_out(db, db.get(Story, i), followed=followed, read_at=read.get(i)) for i in visible_story_ids(db, followed)]


def demo_stories(db: Session) -> list[StoryOut]:
    followed = demo_source_ids(db)
    return [story_out(db, db.get(Story, i), followed=followed, read_at=None) for i in visible_story_ids(db, followed)]


def visible_to(db: Session, story_id: int, source_ids: set[int]) -> bool:
    return bool(
        source_ids
        and db.scalar(
            select(Item.id)
            .where(Item.story_id == story_id, Item.source_id.in_(source_ids), Item.status != "dropped")
            .limit(1)
        )
    )


def mark_read(db: Session, user_id: str, story_id: int) -> datetime:
    now = datetime.now(UTC)
    state = db.get(ReadState, (user_id, story_id)) or ReadState(user_id=user_id, story_id=story_id)
    state.read_at = now
    db.add(state)
    db.commit()
    return now
