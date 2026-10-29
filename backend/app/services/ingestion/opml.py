"""OPML import. Today: loading the seed list (backend/seed/sources.opml) into onboarding
topics and their suggested sources.

The seed file is ours. A reader's own OPML file is untrusted: parse it with external
entities and entity expansion disabled (AGENTS.md, security rules), then discard it."""

import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlparse

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Source, Topic


@dataclass
class SeedSource:
    title: str
    feed_url: str
    html_url: str | None
    type: str


@dataclass
class SeedTopic:
    id: str
    name: str
    description: str
    sources: list[SeedSource] = field(default_factory=list)


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def source_type(feed_url: str) -> str:
    return "arxiv" if urlparse(feed_url).hostname == "rss.arxiv.org" else "feed"


def read_seed(path: Path) -> list[SeedTopic]:
    body = ET.parse(path).getroot().find("body")
    topics = []
    for folder in body if body is not None else []:
        name = folder.get("text") or folder.get("title") or ""
        topic = SeedTopic(id=slug(name), name=name, description=folder.get("description", ""))
        for outline in folder:
            if feed_url := outline.get("xmlUrl"):
                title = outline.get("title") or outline.get("text") or feed_url
                topic.sources.append(SeedSource(title, feed_url, outline.get("htmlUrl"), source_type(feed_url)))
        topics.append(topic)
    return topics


def load_seed(db: Session, path: Path) -> None:
    """Upsert the seed topics and sources. Safe to run on every start."""
    for position, seed in enumerate(read_seed(path)):
        topic = db.get(Topic, seed.id) or Topic(id=seed.id)
        topic.name, topic.description, topic.position = seed.name, seed.description, position
        db.add(topic)
        suggested = []
        for s in seed.sources:
            source = db.scalar(select(Source).where(Source.feed_url == s.feed_url)) or Source(feed_url=s.feed_url)
            source.title, source.html_url, source.type, source.language = s.title, s.html_url, s.type, "en"
            db.add(source)
            suggested.append(source)
        topic.suggested = suggested
    db.commit()
