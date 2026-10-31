"""Readers: created on first sign-in, their onboarding picks, settings and deletion.
Every function takes the signed-in reader; none takes a user id from a request."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.tokens import Claims
from app.db.models import Interest, Source, Subscription, Topic, User
from app.schemas.account import (
    LANGUAGES,
    InterestIn,
    InterestOut,
    LanguageOut,
    MeOut,
    OnboardingIn,
    OnboardingOptions,
    SettingsIn,
    SourceOut,
    SuggestionOut,
    TopicOut,
)
from app.services import interests as research

# Recording "last seen" on every request would make every read a write.
LAST_SEEN_EVERY = timedelta(hours=1)


class UnknownIds(ValueError):
    def __init__(self, what: str, ids: list[str]) -> None:
        super().__init__(f"Unknown {what}: {', '.join(sorted(ids))}")


def _aware(moment: datetime) -> datetime:
    # SQLite hands datetimes back without their time zone; they were stored in UTC.
    return moment if moment.tzinfo else moment.replace(tzinfo=UTC)


def reader_for(db: Session, claims: Claims) -> User:
    """The signed-in reader's row, created the first time they sign in."""
    now = datetime.now(UTC)
    user = db.get(User, claims.user_id)
    if user is None:
        user = User(id=claims.user_id, email=claims.email, display_name=claims.name, created_at=now, last_seen_at=now)
        db.add(user)
        db.commit()
        return user
    if (user.email, user.display_name) != (claims.email, claims.name) or now - _aware(user.last_seen_at) > LAST_SEEN_EVERY:
        user.email, user.display_name, user.last_seen_at = claims.email, claims.name, now
        db.commit()
    return user


def source_out(source: Source) -> SourceOut:
    return SourceOut(
        id=str(source.id),
        name=source.title,
        type=source.type,
        language=source.language,
        url=source.html_url or source.feed_url,
    )


def me(user: User) -> MeOut:
    return MeOut(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        language=user.language,
        kinds=user.kinds,
        topics=[TopicOut(id=t.id, name=t.name, description=t.description) for t in user.topics],
        subscriptions=[source_out(s.source) for s in user.subscriptions],
        interests=[
            InterestOut(id=str(i.id), keywords=i.keywords, related_terms=i.related_terms, categories=i.categories)
            for i in user.interests
        ],
        appearance=user.appearance,
        default_layout=user.default_layout,
        onboarded=user.onboarded_at is not None,
    )


def onboarding_options(db: Session) -> OnboardingOptions:
    topics = db.scalars(select(Topic).order_by(Topic.position)).all()
    return OnboardingOptions(
        languages=[LanguageOut(code=c, native_name=n, english_name=e) for c, (n, e) in LANGUAGES.items()],
        topics=[TopicOut(id=t.id, name=t.name, description=t.description) for t in topics],
        suggestions=[
            SuggestionOut(
                topic_id=t.id,
                kind="paper" if s.type == "arxiv" else "article",
                note="New papers daily" if s.type == "arxiv" else None,
                source=source_out(s),
            )
            for t in topics
            for s in t.suggested
        ],
    )


def _replace_interests(user: User, interests: list[InterestIn]) -> None:
    user.interests = [
        Interest(keywords=i.keywords, related_terms=i.related_terms, categories=i.categories) for i in interests
    ]


def complete_onboarding(db: Session, user: User, picks: OnboardingIn) -> User:
    topics = db.scalars(select(Topic).where(Topic.id.in_(picks.topics)).order_by(Topic.position)).all()
    if missing := set(picks.topics) - {t.id for t in topics}:
        raise UnknownIds("topics", list(missing))
    ids = [int(i) for i in picks.source_ids if i.isdigit()]
    sources = db.scalars(select(Source).where(Source.id.in_(ids))).all()
    if missing := set(picks.source_ids) - {str(s.id) for s in sources}:
        raise UnknownIds("sources", list(missing))

    user.language = picks.language
    user.kinds = list(picks.kinds)
    user.topics = list(topics)
    # Keep the rows that stay (same key), drop the rest, add the new ones.
    wanted = {s.id for s in sources}
    kept = [s for s in user.subscriptions if s.source_id in wanted]
    added = wanted - {s.source_id for s in kept}
    user.subscriptions = kept + [Subscription(source_id=i) for i in sorted(added)]
    _replace_interests(user, picks.interests)
    research.sync_sources(db, user)
    user.onboarded_at = user.onboarded_at or datetime.now(UTC)
    db.commit()
    return user


def replace_interests(db: Session, user: User, interests: list[InterestIn]) -> User:
    _replace_interests(user, interests)
    research.sync_sources(db, user)
    db.commit()
    return user


def update_settings(db: Session, user: User, changes: SettingsIn) -> User:
    if changes.language is not None:
        user.language = changes.language
    if changes.appearance is not None:
        user.appearance = changes.appearance.model_dump()
    if changes.default_layout is not None:
        user.default_layout = changes.default_layout
    db.commit()
    return user


def delete_reader(db: Session, user: User) -> None:
    """Remove the reader and everything they own. Shared sources stay."""
    db.delete(user)
    db.commit()
