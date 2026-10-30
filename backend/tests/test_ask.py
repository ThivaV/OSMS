"""Ask this story's contract: strict questions, cited sentences, and nothing
storable — the request carries no reader id, so there is nothing to log."""

import pytest
from pydantic import ValidationError

from app.schemas.ask import AskRequest, AskResponse

CITED = {"text": "Sources report 1.2 trillion total parameters.", "claim_ids": ["h-c1"]}


def test_question_is_stripped_and_capped() -> None:
    assert AskRequest(question="  How big? ").question == "How big?"
    with pytest.raises(ValidationError):
        AskRequest(question="   ")
    with pytest.raises(ValidationError):
        AskRequest(question="")
    with pytest.raises(ValidationError):
        AskRequest(question="x" * 281)


def test_request_refuses_unknown_fields_and_holds_no_ids() -> None:
    with pytest.raises(ValidationError):
        AskRequest(question="How big?", reader_id="ada")  # type: ignore[call-arg]
    # Nothing to store or log: the question is all there is.
    assert set(AskRequest.model_fields) == {"question"}


def test_reported_answer_needs_cited_sentences() -> None:
    response = AskResponse(question="How big?", reported=True, sentences=[CITED])  # type: ignore[list-item]
    assert response.sentences[0].claim_ids == ["h-c1"]
    with pytest.raises(ValidationError):
        AskResponse(question="How big?", reported=True, sentences=[])
    with pytest.raises(ValidationError):
        AskResponse(question="How big?", reported=True, sentences=[{"text": "Guessing."}])  # type: ignore[list-item]


def test_not_reported_carries_no_sentences() -> None:
    response = AskResponse(question="What does it cost?", reported=False)
    assert response.sentences == []
    with pytest.raises(ValidationError):
        AskResponse(question="What does it cost?", reported=False, sentences=[CITED])  # type: ignore[list-item]


def test_responses_refuse_unknown_fields() -> None:
    with pytest.raises(ValidationError):
        AskResponse(question="How big?", reported=False, quotes=["..."])  # type: ignore[call-arg]
