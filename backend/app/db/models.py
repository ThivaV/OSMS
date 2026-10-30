"""Tables for readers and what they picked. Sign-in itself (Better Auth's users,
sessions and linked accounts) lives in data/auth.db; `users.id` is its user id."""

from datetime import UTC, datetime

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def utcnow() -> datetime:
    return datetime.now(UTC)


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    email: Mapped[str] = mapped_column(String(320))
    display_name: Mapped[str] = mapped_column(String(200), default="")
    language: Mapped[str] = mapped_column(String(8), default="en")
    kinds: Mapped[list[str]] = mapped_column(JSON, default=list)
    appearance: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    default_layout: Mapped[str | None] = mapped_column(String(16), nullable=True)
    onboarded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    topics: Mapped[list["Topic"]] = relationship(secondary="user_topics", order_by="Topic.position")
    subscriptions: Mapped[list["Subscription"]] = relationship(
        cascade="all, delete-orphan", passive_deletes=True, order_by="Subscription.created_at"
    )
    interests: Mapped[list["Interest"]] = relationship(
        cascade="all, delete-orphan", passive_deletes=True, order_by="Interest.id"
    )


class Topic(Base):
    """An onboarding topic: a folder of backend/seed/sources.opml."""

    __tablename__ = "topics"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    description: Mapped[str] = mapped_column(String(200), default="")
    position: Mapped[int] = mapped_column(Integer, default=0)

    suggested: Mapped[list["Source"]] = relationship(secondary="topic_sources", order_by="Source.id")


class UserTopic(Base):
    __tablename__ = "user_topics"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    topic_id: Mapped[str] = mapped_column(ForeignKey("topics.id", ondelete="CASCADE"), primary_key=True)


class Source(Base):
    """A feed OSMS can fetch. Shared: two readers following it means one fetch."""

    __tablename__ = "sources"
    __table_args__ = (UniqueConstraint("feed_url"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    type: Mapped[str] = mapped_column(String(32))
    title: Mapped[str] = mapped_column(String(300))
    feed_url: Mapped[str] = mapped_column(Text)
    html_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    language: Mapped[str] = mapped_column(String(8), default="en")

    # Fetch state (AGENTS.md, *Staying up to date*): conditional requests, its own
    # schedule, and errors that back off rather than drop the source.
    etag: Mapped[str | None] = mapped_column(Text, nullable=True)
    last_modified: Mapped[str | None] = mapped_column(Text, nullable=True)
    last_fetched_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    next_fetch_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    fetch_interval_s: Mapped[int] = mapped_column(Integer, default=3600)
    error_count: Mapped[int] = mapped_column(Integer, default=0)
    last_error: Mapped[str | None] = mapped_column(Text, nullable=True)


class TopicSource(Base):
    __tablename__ = "topic_sources"

    topic_id: Mapped[str] = mapped_column(ForeignKey("topics.id", ondelete="CASCADE"), primary_key=True)
    source_id: Mapped[int] = mapped_column(ForeignKey("sources.id", ondelete="CASCADE"), primary_key=True)


class Subscription(Base):
    __tablename__ = "subscriptions"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    source_id: Mapped[int] = mapped_column(ForeignKey("sources.id", ondelete="CASCADE"), primary_key=True)
    folder: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    source: Mapped[Source] = relationship(lazy="joined")


class Interest(Base):
    """A reader's research interest on arXiv. Personal: never logged, never shared."""

    __tablename__ = "interests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    keywords: Mapped[list[str]] = mapped_column(JSON, default=list)
    related_terms: Mapped[list[str]] = mapped_column(JSON, default=list)
    categories: Mapped[list[str]] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)


class AgentRun(Base):
    """One agent run: which agent decided, on what, and how it ended. Never
    personal data (see app/agent/guardrails.py) and never source text —
    summaries only."""

    __tablename__ = "agent_runs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    agent: Mapped[str] = mapped_column(String(32))
    model: Mapped[str] = mapped_column(String(64))
    prompt_version: Mapped[str] = mapped_column(String(32), default="v1")
    status: Mapped[str] = mapped_column(String(16))  # running, ok, failed, stopped
    stop_reason: Mapped[str | None] = mapped_column(String(32), nullable=True)
    fallback: Mapped[str | None] = mapped_column(String(64), nullable=True)
    input_tokens: Mapped[int] = mapped_column(Integer, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, default=0)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    steps: Mapped[list["AgentStep"]] = relationship(
        cascade="all, delete-orphan", passive_deletes=True, order_by="AgentStep.position"
    )


class AgentStep(Base):
    """One step inside a run: a model call or a tool call, with its reason."""

    __tablename__ = "agent_steps"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    run_id: Mapped[int] = mapped_column(ForeignKey("agent_runs.id", ondelete="CASCADE"), index=True)
    position: Mapped[int] = mapped_column(Integer)
    tool: Mapped[str | None] = mapped_column(String(64), nullable=True)
    arguments: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    result_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    model: Mapped[str] = mapped_column(String(64), default="")
    prompt_version: Mapped[str] = mapped_column(String(32), default="v1")
    input_tokens: Mapped[int] = mapped_column(Integer, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, default=0)
    latency_ms: Mapped[int] = mapped_column(Integer, default=0)
    commentary: Mapped[str | None] = mapped_column(Text, nullable=True)


class Item(Base):
    """One thing a source published: an article, paper, post, video or episode. We keep
    the feed's own excerpt (title, summary, link), never the full article (rule 5)."""

    __tablename__ = "items"
    __table_args__ = (UniqueConstraint("source_id", "guid"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    source_id: Mapped[int] = mapped_column(ForeignKey("sources.id", ondelete="CASCADE"), index=True)
    guid: Mapped[str] = mapped_column(Text)
    link: Mapped[str | None] = mapped_column(Text, nullable=True)
    title: Mapped[str] = mapped_column(Text, default="")
    text: Mapped[str] = mapped_column(Text, default="")
    language: Mapped[str] = mapped_column(String(8), default="en")
    kind: Mapped[str] = mapped_column(String(16), default="article")
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    content_hash: Mapped[str] = mapped_column(String(64))
    # new → ready (processed) or dropped (out of scope, with its reason).
    status: Mapped[str] = mapped_column(String(16), default="new")
    drop_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Companies, products and places it mentions, for clustering.
    names: Mapped[list[str]] = mapped_column(JSON, default=list)
    # Saved first, indexed after: pending → indexed, or failed; skipped for kinds that don't cluster.
    vector_status: Mapped[str] = mapped_column(String(16), default="pending")
    story_id: Mapped[int | None] = mapped_column(ForeignKey("stories.id", ondelete="SET NULL"), nullable=True, index=True)

    source: Mapped[Source] = relationship(lazy="joined")


class Job(Base):
    """The work queue: what to process next. A restart loses nothing; failures retry."""

    __tablename__ = "jobs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    kind: Mapped[str] = mapped_column(String(32))
    ref: Mapped[str] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(16), default="queued", index=True)  # queued, running, done, failed
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    run_after: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    last_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Story(Base):
    """One event, told by many sources. Its title and summary live in `story_summaries`,
    never overwritten: the latest row is the current one."""

    __tablename__ = "stories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)

    items: Mapped[list[Item]] = relationship(order_by="Item.published_at", viewonly=True)


class StorySummary(Base):
    """One version of a story's title and cited summary, by the writer agent."""

    __tablename__ = "story_summaries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    story_id: Mapped[int] = mapped_column(ForeignKey("stories.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(Text)
    # [{"text": "...", "claim_ids": [1, 2]}]: every point cites kept claims.
    points: Mapped[list[dict]] = mapped_column(JSON, default=list)
    model: Mapped[str] = mapped_column(String(64), default="")
    prompt_version: Mapped[str] = mapped_column(String(32), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Claim(Base):
    """A fact one item reported, with the quote it rests on in the source's language.
    Never overwritten: a correction is a new claim that supersedes the old one."""

    __tablename__ = "claims"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    story_id: Mapped[int] = mapped_column(ForeignKey("stories.id", ondelete="CASCADE"), index=True)
    item_id: Mapped[int] = mapped_column(ForeignKey("items.id", ondelete="CASCADE"), index=True)
    statement: Mapped[str] = mapped_column(Text)
    # What it is about ("Price", "Launch date"), and its value in short form ("7.999 kr.").
    subject: Mapped[str] = mapped_column(String(200), default="")
    value: Mapped[str | None] = mapped_column(String(200), nullable=True)
    quote: Mapped[str] = mapped_column(Text)
    quote_language: Mapped[str] = mapped_column(String(8), default="en")
    # The quote in English when the source wrote in another language: "Translated by OSMS".
    translation: Mapped[str | None] = mapped_column(Text, nullable=True)
    # proposed → kept or dropped by the verifier; repeat: kept, but nothing new.
    status: Mapped[str] = mapped_column(String(16), default="proposed", index=True)
    relation: Mapped[str | None] = mapped_column(String(16), nullable=True)  # new, repeat, corrects, conflicts
    related_claim_id: Mapped[int | None] = mapped_column(ForeignKey("claims.id"), nullable=True)
    verifier_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    model: Mapped[str] = mapped_column(String(64), default="")
    prompt_version: Mapped[str] = mapped_column(String(32), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    kept_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    superseded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    superseded_by: Mapped[int | None] = mapped_column(ForeignKey("claims.id"), nullable=True)

    item: Mapped[Item] = relationship(lazy="joined")


class Disagreement(Base):
    """Two kept claims from different sources that cannot both be true, as the
    verifier found them."""

    __tablename__ = "disagreements"
    __table_args__ = (UniqueConstraint("claim_a_id", "claim_b_id"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    story_id: Mapped[int] = mapped_column(ForeignKey("stories.id", ondelete="CASCADE"), index=True)
    claim_a_id: Mapped[int] = mapped_column(ForeignKey("claims.id", ondelete="CASCADE"))
    claim_b_id: Mapped[int] = mapped_column(ForeignKey("claims.id", ondelete="CASCADE"))
    subject: Mapped[str] = mapped_column(String(200), default="")
    note: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class ReadState(Base):
    """When a reader last opened a story: what's new is what was kept after it."""

    __tablename__ = "read_state"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    story_id: Mapped[int] = mapped_column(ForeignKey("stories.id", ondelete="CASCADE"), primary_key=True)
    read_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
