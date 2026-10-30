"""Link safety fails closed; hostile OPML never parses."""

import pytest
from sqlalchemy import select

from app.db.models import Source
from app.services.ingestion.opml import load_seed, read_seed
from app.services.ingestion.safety import (
    MAX_OPML_BYTES,
    UnsafeOpml,
    UnsafeUrl,
    check_url,
    read_user_opml,
)


@pytest.mark.parametrize(
    "url",
    [
        "https://rss.arxiv.org/rss/cs.CL",
        "http://example.com/feed",
        "https://example.com:8080/path?q=1#f",
        "  https://example.com/feed  ",
    ],
)
def test_public_urls_pass(url: str) -> None:
    assert check_url(url).startswith("http")


@pytest.mark.parametrize(
    "url",
    [
        "javascript:alert(1)",
        "file:///etc/passwd",
        "ftp://example.com/feed",
        "https://user:pass@example.com/feed",
        "http://localhost/feed",
        "http://LOCALHOST/feed",
        "http://127.0.0.1/feed",
        "http://10.0.0.5/feed",
        "http://192.168.1.1/feed",
        "http://169.254.169.254/latest/meta-data/",
        "http://[::1]/feed",
        "http://[ff02::1]/feed",
        "http://printer.local/feed",
        "http://intranet/feed",
        "http:///no-host",
        "not a url at all",
    ],
)
def test_unsafe_urls_refuse(url: str) -> None:
    with pytest.raises(UnsafeUrl):
        check_url(url)


def _opml(*outlines: str) -> bytes:
    return (
        "<opml version=\"2.0\"><body><outline text=\"t\">" + "".join(outlines) + "</outline></body></opml>"
    ).encode()


def test_valid_opml_parses() -> None:
    data = _opml(
        '<outline text="A" xmlUrl="https://a.example/feed" htmlUrl="https://a.example/"/>',
        '<outline text="B" xmlUrl="https://b.example/feed"/>',
    )
    assert read_user_opml(data) == [
        ("A", "https://a.example/feed", "https://a.example/"),
        ("B", "https://b.example/feed", None),
    ]


def test_folders_subscribe_to_nothing() -> None:
    assert read_user_opml(_opml('<outline text="just a folder"/>')) == []


def test_entity_declarations_refuse() -> None:
    bomb = (
        b'<?xml version="1.0"?><!DOCTYPE lolz [<!ENTITY lol "lollollol">]>'
        b'<opml version="2.0"><body><outline text="t">'
        b'<outline text="A" xmlUrl="https://a.example/feed"/></outline></body></opml>'
    )
    with pytest.raises(UnsafeOpml):
        read_user_opml(bomb)


def test_oversize_and_floods_refuse() -> None:
    with pytest.raises(UnsafeOpml):
        read_user_opml(b"<opml>" + b"x" * MAX_OPML_BYTES)
    many = _opml(*['<outline text="A" xmlUrl="https://a.example/feed"/>' for _ in range(5001)])
    with pytest.raises(UnsafeOpml):
        read_user_opml(many)


def test_one_bad_url_refuses_the_file() -> None:
    data = _opml(
        '<outline text="A" xmlUrl="https://a.example/feed"/>',
        '<outline text="evil" xmlUrl="http://169.254.169.254/"/>',
    )
    with pytest.raises(UnsafeOpml):
        read_user_opml(data)


def test_unparseable_refuses() -> None:
    with pytest.raises(UnsafeOpml):
        read_user_opml(b"<opml><body>")


def test_seed_honors_per_outline_language(tmp_path, memory_db) -> None:
    seed = tmp_path / "seed.opml"
    seed.write_text(
        "<opml version=\"2.0\"><body><outline text=\"Tech\">"
        '<outline text="Posten" xmlUrl="https://posten.example/feed" language="da"/>'
        '<outline text="Ledger" xmlUrl="https://ledger.example/feed"/>'
        '<outline text="Mystery" xmlUrl="https://mystery.example/feed" language="xx"/>'
        "</outline></body></opml>"
    )
    assert [s.language for s in read_seed(seed)[0].sources] == ["da", "en", "en"]
    load_seed(memory_db, seed)
    languages = {
        s.feed_url: s.language for s in memory_db.scalars(select(Source)).all()
    }
    assert languages == {
        "https://posten.example/feed": "da",
        "https://ledger.example/feed": "en",
        "https://mystery.example/feed": "en",
    }
