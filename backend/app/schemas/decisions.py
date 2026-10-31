"""How OSMS decided, on the wire: one entry per agent run behind a story."""

from datetime import datetime

from pydantic import BaseModel


class DecisionOut(BaseModel):
    id: str
    agent: str  # triage, judge, claims, verifier, writer, illustration
    model: str
    #: The backup model that answered instead, if the route's own couldn't.
    fallback: str | None = None
    prompt_version: str
    at: datetime
    latency_ms: int | None = None
    input_tokens: int
    output_tokens: int
    #: The item the run decided about, and its source; None for the story itself.
    about: str | None = None
    source: str | None = None
    #: What the model said, when its answer carries a reason.
    reason: str | None = None
    #: What it changed, read from the story's history.
    outcome: str | None = None


class DecisionsOut(BaseModel):
    decisions: list[DecisionOut]
