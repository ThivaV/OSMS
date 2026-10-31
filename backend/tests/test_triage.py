"""Triage: Muse Glimmer checks every item; Muse Spark decides what it is unsure about,
and what it keeps that the word list calls political; the word list stands in when
neither can answer. Names come back in the shape clustering compares."""

from datetime import UTC, datetime

import httpx
import pytest

from app.agent.decision_log import DecisionLog
from app.agent.kit import AgentKit
from app.agent.runtime import ModelRoute, ModelStep, ModelUsage, Runner
from app.clients.openai_compat import local_model_ready
from app.db.models import AgentRun, Item, Source
from app.services.names import from_listed
from app.services.triage import triage

GLIMMER = ModelRoute(model="muse-glimmer-30b", endpoint="http://127.0.0.1:11434/v1", effort="low")
SPARK = ModelRoute(model="muse-spark-1.3", endpoint="https://api.meta.ai/v1", effort="low")


def verdict(**overrides) -> dict:
    return {
        "in_scope": True,
        "noise": False,
        "language": "da",
        "names": ["Lumen", "Fold"],
        "sure": True,
        "reason": "A product launch.",
    } | overrides


class Script:
    def __init__(self, answers: list[dict]) -> None:
        self.answers = answers
        self.asked = 0

    def step(self, *, system, messages, tools, agent, schema=None, effort=None) -> ModelStep:
        self.asked += 1
        if not self.answers:
            raise AssertionError("asked more than scripted")
        return ModelStep(final=self.answers.pop(0), reason="scripted", usage=ModelUsage(40, 10))


def kit(db, route: ModelRoute, answers: list[dict] | None) -> AgentKit:
    """None: the model isn't there (Ollama stopped, or no key)."""
    script = Script(answers or [])
    built = AgentKit(
        runner=Runner(script, DecisionLog(db)), routes={"triage": route}, available={"triage": answers is not None}
    )
    built.script = script  # type: ignore[attr-defined]
    return built


@pytest.fixture
def item(memory_db) -> Item:
    source = Source(type="feed", title="Bytebladet", feed_url="https://bytebladet.example/rss", language="da")
    memory_db.add(source)
    memory_db.flush()
    found = Item(
        source_id=source.id,
        guid="g",
        title="Lumen Fold kommer til Danmark",
        text="Lumen Fold koster 7.999 kr.",
        language="en",
        published_at=datetime.now(UTC),
        content_hash="h",
    )
    memory_db.add(found)
    memory_db.commit()
    return found


def test_a_sure_verdict_from_glimmer_decides_alone(memory_db, item) -> None:
    glimmer, spark = kit(memory_db, GLIMMER, [verdict(names=["Lumen Fold", "Danmark"])]), kit(memory_db, SPARK, [])
    result = triage(glimmer, spark, item)
    assert (result.drop_reason, result.language, result.decided_by) == (None, "da", "muse-glimmer-30b")
    assert result.names == ["lumen", "fold", "danmark"]
    assert spark.script.asked == 0


def test_out_of_scope_and_noise_are_dropped_with_the_reason(memory_db, item) -> None:
    out = triage(kit(memory_db, GLIMMER, [verdict(in_scope=False, reason="An election story.")]), None, item)
    assert out.drop_reason == "rule 3 (muse-glimmer-30b): An election story."
    advert = triage(kit(memory_db, GLIMMER, [verdict(noise=True, reason="A giveaway.")]), None, item)
    assert advert.drop_reason == "noise (muse-glimmer-30b): A giveaway."


def test_unsure_items_go_to_muse_spark_which_decides(memory_db, item) -> None:
    glimmer = kit(memory_db, GLIMMER, [verdict(sure=False)])
    spark = kit(memory_db, SPARK, [verdict(in_scope=False, reason="About a government decision.")])
    result = triage(glimmer, spark, item)
    assert result.decided_by == "muse-spark-1.3" and result.drop_reason.startswith("rule 3 (muse-spark-1.3)")
    runs = [(r.agent, r.model) for r in memory_db.query(AgentRun).order_by(AgentRun.id)]
    assert runs == [("triage", "muse-glimmer-30b"), ("triage", "muse-spark-1.3")]


def test_keeping_what_the_word_list_calls_political_needs_muse_spark(memory_db, item) -> None:
    item.title = "Folketinget vil regulere Lumen Fold"
    glimmer = kit(memory_db, GLIMMER, [verdict()])
    spark = kit(memory_db, SPARK, [verdict(in_scope=False, reason="Parliament's plans.")])
    assert triage(glimmer, spark, item).decided_by == "muse-spark-1.3"
    # No Muse Spark to ask: the list's drop stands.
    alone = triage(kit(memory_db, GLIMMER, [verdict()]), kit(memory_db, SPARK, None), item)
    assert (alone.decided_by, alone.drop_reason) == ("word list", "rule 3: political ('folketinget')")


def test_without_models_the_word_list_stands_in(memory_db, item) -> None:
    kept = triage(kit(memory_db, GLIMMER, None), kit(memory_db, SPARK, None), item)
    assert (kept.drop_reason, kept.language, kept.decided_by) == (None, None, "word list")
    assert "lumen" in kept.names
    # Glimmer unsure and Muse Spark unavailable: Glimmer's leaning stands.
    leaning = triage(
        kit(memory_db, GLIMMER, [verdict(sure=False, noise=True, reason="Looks like an advert.")]), None, item
    )
    assert leaning.drop_reason == "noise (muse-glimmer-30b): Looks like an advert."


def test_a_failed_glimmer_call_falls_back(memory_db, item) -> None:
    broken = kit(memory_db, GLIMMER, [{"not": "a verdict"}])
    assert triage(broken, None, item).decided_by == "word list"


def test_listed_names_become_the_tokens_clustering_compares() -> None:
    assert from_listed(["iPhone 17 Pro", "Apple", "the", "OpenAI", "apple"]) == ["iphone", "pro", "apple", "openai"]


def test_a_stopped_server_or_a_missing_model_reads_as_unavailable() -> None:
    def server(models: list[str]):
        listing = {"data": [{"id": m} for m in models]}
        return httpx.Client(transport=httpx.MockTransport(lambda r: httpx.Response(200, json=listing)))

    def stopped(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("refused")

    base = "http://127.0.0.1:11434/v1"
    assert local_model_ready(base, "muse-glimmer-30b", http=server(["muse-glimmer-30b:latest"]))
    assert not local_model_ready(base, "muse-glimmer-30b", http=server(["llama3:latest"]))
    assert not local_model_ready(base, "muse-glimmer-30b", http=httpx.Client(transport=httpx.MockTransport(stopped)))


def test_glimmer_on_ollama_answers_in_its_own_turn_format() -> None:
    import json

    from app.clients.ollama import OllamaEndpoint
    from app.clients.openai_compat import models_from_settings
    from app.config import Settings

    sent = []

    def ollama(request: httpx.Request) -> httpx.Response:
        sent.append(json.loads(request.content))
        return httpx.Response(200, json={"response": json.dumps(verdict()), "prompt_eval_count": 300, "eval_count": 40})

    endpoint = OllamaEndpoint("http://127.0.0.1:11434/v1", http=httpx.Client(transport=httpx.MockTransport(ollama)))
    step = endpoint.complete(
        model="muse-glimmer-30b",
        system="Check the item.",
        messages=[{"role": "user", "content": "ITEM"}],
        tools=[],
        schema={"type": "object"},
        effort="low",
    )
    assert step.final["in_scope"] is True and step.reason == "A product launch." and step.usage.output_tokens == 40
    body = sent[0]
    assert body["raw"] is True and body["format"] == {"type": "object"} and "reasoning_effort" not in body
    assert body["prompt"].startswith("<|start|>system<|message|>Check the item.")
    assert body["prompt"].endswith("<|start|>user<|message|>ITEM<|eot|><|start|>assistant to=user<|message|>")
    models = models_from_settings(Settings(_env_file=None))
    assert isinstance(models.endpoints["http://127.0.0.1:11434/v1"], OllamaEndpoint)


def test_an_ollama_error_never_carries_its_body() -> None:
    from app.agent.runtime import ModelError
    from app.clients.ollama import OllamaEndpoint

    secret = httpx.Client(transport=httpx.MockTransport(lambda r: httpx.Response(500, text="echo: ITEM text")))
    with pytest.raises(ModelError) as error:
        OllamaEndpoint("http://127.0.0.1:11434/v1", http=secret).complete(
            model="muse-glimmer-30b", system="s", messages=[], tools=[], schema={}
        )
    assert "ITEM" not in str(error.value)
