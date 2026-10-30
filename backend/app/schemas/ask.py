"""Ask this story: one typed question, answered only from the story's verified
claims — or "Not reported yet". Nothing is stored or logged: the request
carries no reader id and no story id beyond the URL, and the response carries
no quotes, only cited sentences."""

from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

from app.schemas.account import Strict

# One typed sentence, capped like the app's field. Blank counts as missing.
Question = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=280)]
Sentence = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=2000)]
ClaimId = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=64)]


class AskRequest(Strict):
    question: Question


class CitedSentence(BaseModel):
    """One answer sentence and the verified claims it rests on. Code drops any
    sentence that doesn't cite one, before the reader sees it."""

    model_config = ConfigDict(extra="forbid")

    text: Sentence
    claim_ids: Annotated[list[ClaimId], Field(min_length=1, max_length=20)]


class AskResponse(BaseModel):
    """`reported=False` is "Not reported yet": no sentences, no guessing."""

    model_config = ConfigDict(extra="forbid")

    question: str
    reported: bool
    sentences: list[CitedSentence] = []

    @model_validator(mode="after")
    def _cited_or_not_reported(self) -> "AskResponse":
        if self.reported and not self.sentences:
            raise ValueError("a reported answer needs at least one cited sentence")
        if not self.reported and self.sentences:
            raise ValueError("a not-reported answer carries no sentences")
        return self
