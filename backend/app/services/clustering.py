"""Incremental story assignment: does a new item join a story, start one, or need the
judge? The rule is the author's (decided Oct 30): an item joins with no model only when
it is close in meaning, close in time and names the same things. Any other similar pair
goes to the judge, and when the judge is unsure they stay apart, because an unneeded
split is easier to repair than a wrong merge.

The numbers below are provisional. The author sets them with the eval (AGENTS.md §12);
nothing else may change them."""

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Literal


@dataclass(frozen=True)
class Thresholds:
    #: Dense cosine at or above this is close in meaning (provisional).
    join: float = 0.82
    #: Below this, a different story; between the two, the judge decides (provisional).
    consider: float = 0.68
    #: Close in time: published within this of each other (provisional).
    window: timedelta = timedelta(hours=72)
    #: How many neighbours the judge may see for one item.
    judge_limit: int = 3


DEFAULT_THRESHOLDS = Thresholds()


@dataclass(frozen=True)
class Candidate:
    item_id: int
    story_id: int | None
    similarity: float
    published_at: datetime
    names: tuple[str, ...]


@dataclass(frozen=True)
class Decision:
    action: Literal["join", "judge", "new"]
    reason: str
    story_id: int | None = None
    #: For "judge": the neighbours to ask about, best first.
    ask: tuple[Candidate, ...] = ()


def decide(
    published_at: datetime, names: tuple[str, ...], candidates: list[Candidate], thresholds: Thresholds = DEFAULT_THRESHOLDS
) -> Decision:
    in_window = [
        c
        for c in candidates
        if c.story_id is not None
        and abs(c.published_at - published_at) <= thresholds.window
        and c.similarity >= thresholds.consider
    ]
    if not in_window:
        return Decision("new", "nothing close in meaning and time")
    in_window.sort(key=lambda c: c.similarity, reverse=True)
    for c in in_window:
        shared = set(names) & set(c.names)
        if c.similarity >= thresholds.join and shared:
            return Decision("join", f"similarity {c.similarity:.2f}, shares {sorted(shared)[:3]}", story_id=c.story_id)
    # Similar, but not clearly the same: one question per story, best neighbour first.
    asked: list[Candidate] = []
    for c in in_window:
        if c.story_id not in {a.story_id for a in asked}:
            asked.append(c)
    return Decision(
        "judge",
        f"similarity {in_window[0].similarity:.2f} without the names to be sure",
        ask=tuple(asked[: thresholds.judge_limit]),
    )
