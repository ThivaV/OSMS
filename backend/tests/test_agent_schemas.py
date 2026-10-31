"""Lists a model must fill are required in the schema it is sent. Given a default, the
JSON schema marks a list optional, and Muse Spark answered the writer with a title and
no points: 29 summaries in a row came back empty (Oct 31)."""

import pytest

from app.services import ask, briefing, writer


@pytest.mark.parametrize(
    ("schema", "field"),
    [
        (writer.WriterOut, "points"),
        (writer.PointOut, "claim_ids"),
        (briefing.ScriptOut, "chapters"),
        (briefing._Chapter, "sentences"),
        (briefing._Sentence, "claim_ids"),
        (briefing.EditorOut, "picks"),
        (ask._SentenceOut, "claim_ids"),
    ],
)
def test_lists_the_model_must_fill_are_required(schema, field) -> None:
    assert field in schema.model_json_schema()["required"]
