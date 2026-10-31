"""Research interests on arXiv: each becomes one shared search, fetched like a feed; new
papers are matched to readers by the words they use, each match says why, and nobody sees
anyone else's (rule 7). The arXiv responses here are invented, never saved copies."""

from datetime import timedelta
from urllib.parse import parse_qs, urlparse

from sqlalchemy import select

from app.db.models import InterestMatch, Item, Source
from app.services import interests, jobs
from app.services.ingestion import scheduler
from tests.test_pipeline import FEEDS, NOW, AgentScript, _drain, _pipeline

RAG = {"keywords": ["retrieval-augmented generation"], "related_terms": ["RAG"], "categories": ["cs.CL"]}


def atom(entries: list[tuple[str, str, str, int]]) -> bytes:
    body = "".join(
        f"<entry><id>https://arxiv.example/abs/{pid}</id><title>{title}</title><summary>{abstract}</summary>"
        f"<published>{(NOW - timedelta(days=age)):%Y-%m-%dT%H:%M:%SZ}</published>"
        f'<link href="https://arxiv.example/abs/{pid}" rel="alternate" type="text/html"/></entry>'
        for pid, title, abstract, age in entries
    )
    return f'<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><title>ArXiv Query</title>{body}</feed>'.encode()


def test_the_same_words_make_the_same_search() -> None:
    url = interests.query_url(["retrieval-augmented generation"], ["RAG"], ["cs.CL"])
    query = parse_qs(urlparse(url).query)
    assert urlparse(url).netloc == "export.arxiv.org"
    assert query["search_query"] == [
        '(ti:rag OR abs:rag OR ti:"retrieval-augmented generation" OR abs:"retrieval-augmented generation") AND (cat:cs.CL)'
    ]
    assert query["sortBy"] == ["submittedDate"] and query["max_results"] == ["100"]
    # Order, case and repeats don't make a different search.
    assert interests.query_url(["RAG", "Retrieval-Augmented Generation"], ["rag"], ["cs.CL"]) == url


def test_readers_with_the_same_words_share_one_search_that_names_nobody(client, auth) -> None:
    for reader in ("ada", "grace"):
        client.get("/me", headers=auth(reader))
        assert client.put("/me/interests", json={"interests": [RAG]}, headers=auth(reader)).status_code == 200
    with client.app.state.sessions() as db:
        searches = list(db.scalars(select(Source).where(Source.type == "arxiv-query")))
        assert len(searches) == 1 and searches[0].title == "arXiv search"
        assert searches[0] in scheduler.followed_sources(db)


def test_new_papers_reach_the_readers_whose_words_they_use(client, auth, tmp_path) -> None:
    client.get("/me", headers=auth("ada"))
    client.get("/me", headers=auth("grace"))
    client.put("/me/interests", json={"interests": [RAG]}, headers=auth("ada"))
    client.put("/me/interests", json={"interests": [{"keywords": ["protein folding"]}]}, headers=auth("grace"))
    FEEDS["export.arxiv.org"] = atom(
        [
            ("2610.01234v2", "Retrieval-Augmented Generation for Danish questions", "We study RAG for Danish.", 20),
            ("2610.04321v1", "A faster sorting network", "Nothing about either interest.", 2),
            ("2609.00001v1", "An old RAG paper", "Too old for the backfill.", 45),
        ]
    )
    with client.app.state.sessions() as db:
        search = db.scalar(select(Source).where(Source.type == "arxiv-query"))
        pipeline = _pipeline(db, tmp_path, AgentScript({}), available=False)
        jobs.enqueue(db, "fetch-source", search.id)
        db.commit()
        _drain(db, pipeline)
        papers = {i.title: i for i in db.scalars(select(Item).where(Item.source_id == search.id))}
        assert set(papers) == {"Retrieval-Augmented Generation for Danish questions", "A faster sorting network"}
        assert all(p.kind == "paper" for p in papers.values())
        assert [m.matched_terms for m in db.scalars(select(InterestMatch))] == [
            ["retrieval-augmented generation", "RAG"]
        ]
        assert search.next_fetch_at is not None  # daily, like the category feeds

    ada = client.get("/me/research", headers=auth("ada")).json()["papers"]
    assert [(p["title"], p["matched_terms"]) for p in ada] == [
        ("Retrieval-Augmented Generation for Danish questions", ["retrieval-augmented generation", "RAG"])
    ]
    assert client.get("/me/research", headers=auth("grace")).json() == {"papers": []}
    assert client.get("/me/research").status_code == 401


def test_an_interest_with_categories_ignores_other_categories_feeds(memory_db) -> None:
    from app.db.models import Interest, User

    memory_db.add(User(id="ada", email="ada@reader.example"))
    interest = Interest(
        user_id="ada", keywords=["diffusion"], categories=["cs.CV"], query_url="https://export.arxiv.org/q"
    )
    feed = Source(type="arxiv", title="arXiv cs.LG", feed_url="https://rss.arxiv.example/rss/cs.LG")
    vision = Source(type="arxiv", title="arXiv cs.CV", feed_url="https://rss.arxiv.example/rss/cs.CV")
    memory_db.add_all([interest, feed, vision])
    memory_db.flush()
    papers = [
        Item(
            source_id=s.id,
            guid=s.title,
            title="Diffusion models, again",
            text="",
            language="en",
            kind="paper",
            published_at=NOW,
            content_hash=s.title,
        )
        for s in (feed, vision)
    ]
    memory_db.add_all(papers)
    memory_db.flush()
    assert [interests.match_paper(memory_db, p) for p in papers] == [0, 1]


def test_paper_ids_come_from_the_abstract_link() -> None:
    assert interests.paper_id("https://arxiv.org/abs/2610.01234v2") == ("2610.01234", 2)
    assert interests.paper_id("https://arxiv.org/abs/2610.01234") == ("2610.01234", None)
    assert interests.paper_id("https://example.org/x") == (None, None)


def test_interests_saved_before_searches_existed_get_one(memory_db) -> None:
    from app.db.models import Interest, User

    memory_db.add(User(id="ada", email="ada@reader.example"))
    memory_db.add(Interest(user_id="ada", keywords=["protein folding"]))
    memory_db.commit()
    assert interests.sync_all(memory_db) == 1
    assert memory_db.scalar(select(Interest.query_url)).startswith(interests.ARXIV_API)
    assert interests.sync_all(memory_db) == 0


class InterestModels:
    """A fake interest agent: answers as scripted, records what it was sent."""

    def __init__(self, answer: dict) -> None:
        from app.agent.runtime import ModelRoute

        self.routes = {"interest": ModelRoute(model="muse-spark-1.3", endpoint="https://api.meta.ai/v1")}
        self.answer = answer
        self.prompts: list[str] = []

    def available(self, agent: str) -> bool:
        return agent == "interest"

    def step(self, *, system, messages, tools, agent, schema=None, effort=None):
        from app.agent.runtime import ModelStep, ModelUsage

        self.prompts.append(messages[-1]["content"])
        return ModelStep(
            final=self.answer, reason="Suggested for retrieval-augmented generation", usage=ModelUsage(90, 40)
        )


def test_the_interest_agent_suggests_terms_and_categories_and_flags_politics(tmp_path, auth) -> None:
    from fastapi.testclient import TestClient

    from app.auth.tokens import TokenVerifier
    from app.config import Settings
    from app.db.models import AgentStep
    from app.main import create_app
    from tests.conftest import AUDIENCE, ISSUER, KEY, StaticKeys

    models = InterestModels(
        {
            "related_terms": [
                "RAG",
                "retrieval-augmented generation",
                "dense retrieval",
                "rag",
                "election forecasting",
            ],
            "categories": ["cs.CL", "physics.soc-ph", "cs.IR", "cs.CL"],
            "flagged": ["election polling", "not a keyword"],
        }
    )
    app = create_app(
        Settings(_env_file=None, database_url=f"sqlite:///{tmp_path / 'x.db'}"),
        TokenVerifier(issuer=ISSUER, audience=AUDIENCE, keys=StaticKeys(KEY.public_key())),
        models=models,
    )
    with TestClient(app) as client:
        client.get("/me", headers=auth("ada"))
        body = client.post(
            "/me/interests/suggest",
            json={"keywords": ["retrieval-augmented generation", "election polling"]},
            headers=auth("ada"),
        ).json()
        assert body["related_terms"] == ["RAG", "dense retrieval"]  # no keyword, no repeat, nothing political
        assert body["categories"] == ["cs.CL", "cs.IR"]  # only OSMS's categories
        assert body["flagged"] == ["election polling"]
        assert "retrieval-augmented generation" in models.prompts[0] and "ada" not in models.prompts[0]
        with client.app.state.sessions() as db:
            step = db.scalar(select(AgentStep))
            assert "retrieval-augmented generation" not in (step.reason or "")  # redacted from the log
        assert client.post("/me/interests/suggest", json={"keywords": []}, headers=auth("ada")).status_code == 422
        assert client.post("/me/interests/suggest", json={"keywords": ["x"]}).status_code == 401


def test_without_the_interest_agent_suggestions_are_unavailable(client, auth) -> None:
    client.get("/me", headers=auth("ada"))
    assert (
        client.post("/me/interests/suggest", json={"keywords": ["protein folding"]}, headers=auth("ada")).status_code
        == 503
    )
