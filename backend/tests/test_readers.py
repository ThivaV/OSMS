"""Onboarding, settings, deletion, and rule 7: one reader's data never reaches another."""

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select

from app.config import Settings
from app.db.models import Interest, Source, Subscription, UserTopic

INTEREST = {"keywords": ["retrieval-augmented generation", "RAG"], "related_terms": ["reranking"], "categories": ["cs.CL"]}


def ai_sources(client: TestClient) -> list[str]:
    options = client.get("/onboarding/options").json()
    return [s["source"]["id"] for s in options["suggestions"] if s["topic_id"] == "ai-research"]


def onboard(client: TestClient, headers, **changes) -> dict:
    picks = {
        "language": "da",
        "topics": ["ai-research"],
        "kinds": ["article", "paper"],
        "source_ids": ai_sources(client),
        "interests": [INTEREST],
    } | changes
    response = client.put("/me/onboarding", headers=headers, json=picks)
    assert response.status_code == 200, response.text
    return response.json()


def test_onboarding_options_come_from_the_seed_list(client: TestClient) -> None:
    options = client.get("/onboarding/options").json()
    assert [lang["code"] for lang in options["languages"]] == ["en", "da", "ta"]
    assert [t["id"] for t in options["topics"]][:2] == ["ai-research", "developer-tools"]
    arxiv = [s for s in options["suggestions"] if s["source"]["type"] == "arxiv"]
    assert arxiv and all(s["kind"] == "paper" for s in arxiv)


def test_onboarding_saves_the_picks(client: TestClient, auth) -> None:
    me = onboard(client, auth("ada"))
    assert me["onboarded"] is True
    assert me["language"] == "da"
    assert [t["id"] for t in me["topics"]] == ["ai-research"]
    assert {s["id"] for s in me["subscriptions"]} == set(ai_sources(client))
    assert me["interests"][0]["keywords"] == INTEREST["keywords"]
    assert client.get("/me", headers=auth("ada")).json() == me


def test_onboarding_again_keeps_what_overlaps(client: TestClient, auth) -> None:
    sources = ai_sources(client)
    onboard(client, auth("ada"), source_ids=sources)
    me = onboard(client, auth("ada"), source_ids=sources[:2], interests=[])
    assert {s["id"] for s in me["subscriptions"]} == set(sources[:2])
    assert me["interests"] == []


def test_onboarding_refuses_bad_picks(client: TestClient, auth) -> None:
    good = {"language": "en", "topics": [], "kinds": [], "source_ids": []}
    bad = [
        {"topics": ["no-such-topic"]},
        {"source_ids": ["999999"]},
        {"language": "fr"},
        {"kinds": ["podcast"]},
        {"surprise": True},
        {"interests": [{"keywords": []}]},
        {"interests": [{"keywords": ["x" * 101]}]},
        {"interests": [{"keywords": ["ok"], "categories": ["not a category"]}]},
        {"source_ids": [str(i) for i in range(501)]},
    ]
    for change in bad:
        response = client.put("/me/onboarding", headers=auth("ada"), json=good | change)
        assert response.status_code == 422, change


def test_settings_follow_the_reader(client: TestClient, auth) -> None:
    appearance = {"mode": "dark", "palette_id": "nordlys", "pure_black": True, "reading_font": "sans",
                  "reading_scale": 1.2, "glass": "tinted"}
    response = client.patch("/me/settings", headers=auth("ada"), json={"appearance": appearance, "default_layout": "card"})
    assert response.status_code == 200
    me = client.get("/me", headers=auth("ada")).json()
    assert me["appearance"] == appearance
    assert me["default_layout"] == "card"
    too_big = client.patch("/me/settings", headers=auth("ada"), json={"appearance": appearance | {"reading_scale": 3}})
    assert too_big.status_code == 422


def test_research_interests_can_be_replaced(client: TestClient, auth) -> None:
    onboard(client, auth("ada"))
    new = {"keywords": ["exoplanet atmospheres"], "categories": ["astro-ph.EP"]}
    me = client.put("/me/interests", headers=auth("ada"), json={"interests": [new]}).json()
    assert [i["keywords"] for i in me["interests"]] == [["exoplanet atmospheres"]]


def test_one_reader_never_sees_another(client: TestClient, auth) -> None:
    onboard(client, auth("ada"))
    grace = client.get("/me", headers=auth("grace")).json()
    assert grace["topics"] == grace["subscriptions"] == grace["interests"] == []
    assert grace["email"] == "grace@users.example"

    client.patch("/me/settings", headers=auth("grace"), json={"language": "ta"})
    client.put("/me/interests", headers=auth("grace"), json={"interests": []})
    assert client.delete("/me", headers=auth("grace")).status_code == 204

    ada = client.get("/me", headers=auth("ada")).json()
    assert ada["language"] == "da"
    assert ada["interests"][0]["keywords"] == INTEREST["keywords"]
    assert len(ada["subscriptions"]) == len(ai_sources(client))


def test_delete_removes_everything_the_reader_owns(client: TestClient, auth, settings: Settings) -> None:
    onboard(client, auth("ada"))
    assert client.delete("/me", headers=auth("ada")).status_code == 204

    with create_engine(settings.database_url).connect() as db:
        for table in (Subscription, UserTopic, Interest):
            assert db.scalar(select(func.count()).select_from(table)) == 0, table.__tablename__
        assert db.scalar(select(func.count()).select_from(Source)) > 0, "shared sources stay"

    again = client.get("/me", headers=auth("ada")).json()
    assert again["onboarded"] is False, "signing in again starts a new, empty account"
