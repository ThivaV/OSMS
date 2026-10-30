"""The clustering rule, decided Oct 30: join with no model only when close in meaning,
close in time and naming the same things; anything else similar goes to the judge."""

from datetime import UTC, datetime, timedelta

from app.services.clustering import Candidate, Thresholds, decide

NOW = datetime(2026, 10, 30, 12, tzinfo=UTC)
T = Thresholds(join=0.82, consider=0.68, window=timedelta(hours=72))


def c(story: int | None, similarity: float, hours: float = 1, names: tuple[str, ...] = ("lumen", "fold")) -> Candidate:
    return Candidate(item_id=story or 0, story_id=story, similarity=similarity, published_at=NOW - timedelta(hours=hours), names=names)


def test_close_in_meaning_time_and_names_joins_without_a_model() -> None:
    d = decide(NOW, ("lumen", "fold"), [c(1, 0.91)], T)
    assert (d.action, d.story_id) == ("join", 1)


def test_similar_without_shared_names_asks_the_judge() -> None:
    d = decide(NOW, ("lumen", "fold"), [c(1, 0.91, names=("kestrel",))], T)
    assert d.action == "judge" and [a.story_id for a in d.ask] == [1]
    # No names at all (triage unsure, or cut): the judge decides.
    assert decide(NOW, (), [c(1, 0.95)], T).action == "judge"


def test_between_the_thresholds_asks_the_judge_once_per_story() -> None:
    d = decide(NOW, ("lumen",), [c(1, 0.75), c(1, 0.74), c(2, 0.70)], T)
    assert d.action == "judge" and [a.story_id for a in d.ask] == [1, 2]


def test_far_apart_in_time_or_meaning_starts_a_new_story() -> None:
    assert decide(NOW, ("lumen", "fold"), [c(1, 0.95, hours=24 * 21)], T).action == "new"  # three weeks apart
    assert decide(NOW, ("lumen", "fold"), [c(1, 0.50)], T).action == "new"
    assert decide(NOW, ("lumen",), [c(None, 0.99)], T).action == "new"  # a neighbour not yet in a story
