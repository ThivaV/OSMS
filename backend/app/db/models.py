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
