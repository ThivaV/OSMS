"""Ask this story (secondary, rule 4): one typed question, answered by the ask agent
(Muse Spark, no backup) from the story's checked facts only, or "Not reported yet".

A typed question counts like research keywords: the prompt holds the question and the
facts, never who asked; the decision log redacts the question even from free text; and
neither the question nor the answer is stored."""

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from app.agent.kit import AgentKit
from app.agent.prompts import load
from app.db.models import Story
from app.schemas.ask import AskResponse, CitedSentence
from app.services.stories import _source
from app.services.verifier import current_claims


class _SentenceOut(BaseModel):
    model_config = ConfigDict(extra="ignore")

    text: str = Field(min_length=1, max_length=600)
    claim_ids: list[int] = Field(min_length=1, max_length=8)  # required: see writer.WriterOut


class AskOut(BaseModel):
    model_config = ConfigDict(extra="ignore", title="story_answer")

    reported: bool
    sentences: list[_SentenceOut] = Field(default_factory=list, max_length=6)


class AskUnavailable(RuntimeError):
    """The ask agent couldn't answer: the app shows its unavailable state."""


def answer(db: Session, kit: AgentKit, story: Story, question: str, *, followed: set[int]) -> AskResponse:
    if not kit.can("ask"):
        raise AskUnavailable("the ask agent isn't configured")
    facts = [c for c in current_claims(db, story.id) if c.status == "kept"]
    if not facts:
        return AskResponse(question=question, reported=False)
    prompt = load("ask")
    listed = "\n".join(f"id {c.id}. {c.statement} | source: {c.item.source.title}" for c in facts)
    result = kit.runner.call_once(
        kit.spec("ask", prompt_version=prompt.version, max_steps=2, token_budget=8_000, sensitive=(question,)),
        system=prompt.text,
        user=f"<facts>\n{listed}\n</facts>\n\n<question>{question}</question>",
        schema=AskOut,
    )
    if result.status != "ok" or result.value is None:
        raise AskUnavailable(result.stop_reason or "failed")
    out = AskOut.model_validate(result.value)
    by_id = {c.id: c for c in facts}
    sentences = []
    for s in out.sentences if out.reported else []:
        cited = [by_id[i] for i in s.claim_ids if i in by_id]
        if not cited:
            continue  # Code drops any sentence that cites nothing the story has.
        sources = []
        for c in cited:
            if c.item.source not in sources:
                sources.append(c.item.source)
        sentences.append(
            CitedSentence(
                text=s.text.strip(), claim_ids=[str(c.id) for c in cited], sources=[_source(x, followed) for x in sources]
            )
        )
    return AskResponse(question=question, reported=bool(sentences), sentences=sentences)
