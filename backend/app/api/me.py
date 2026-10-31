"""The signed-in reader: profile, onboarding picks, research interests, settings and
"Delete my account". Every route acts on the reader the token names, and only them."""

from typing import Annotated

from fastapi import APIRouter, HTTPException, Request, Response, status
from pydantic import Field

from app.api.deps import Db, Kit, Reader
from app.api.stories import _within_limit
from app.schemas.account import MAX_TERMS, InterestsIn, MeOut, OnboardingIn, OnboardingOptions, SettingsIn, Strict, Term
from app.schemas.stories import PaperOut, ResearchOut
from app.services import accounts, interest_agent, stories
from app.services import interests as research

router = APIRouter()

#: The interest agent runs as the reader types (debounced): a looser limit than asking.
SUGGEST_LIMIT = 30


@router.get("/onboarding/options")
def onboarding_options(db: Db) -> OnboardingOptions:
    """Public: the languages, topics and suggested sources onboarding offers."""
    return accounts.onboarding_options(db)


@router.get("/me")
def read_me(reader: Reader) -> MeOut:
    return accounts.me(reader)


@router.put("/me/onboarding")
def complete_onboarding(picks: OnboardingIn, reader: Reader, db: Db) -> MeOut:
    try:
        return accounts.me(accounts.complete_onboarding(db, reader, picks))
    except accounts.UnknownIds as error:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(error))


@router.put("/me/interests")
def replace_interests(body: InterestsIn, reader: Reader, db: Db) -> MeOut:
    return accounts.me(accounts.replace_interests(db, reader, body.interests))


@router.patch("/me/settings")
def update_settings(changes: SettingsIn, reader: Reader, db: Db) -> MeOut:
    return accounts.me(accounts.update_settings(db, reader, changes))


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(reader: Reader, db: Db, request: Request) -> Response:
    """Deletes the reader's OSMS data. The app then deletes the sign-in account itself."""
    accounts.delete_reader(db, reader, briefings_dir=request.app.state.briefings_dir)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me/research")
def my_research(reader: Reader, db: Db) -> ResearchOut:
    """New arXiv papers for the reader's research interests: theirs alone (rule 7)."""
    papers = []
    for item, terms in research.research_for(db, reader.id):
        arxiv_id, version = research.paper_id(item.link)
        papers.append(
            PaperOut(
                id=str(item.id),
                title=item.title,
                abstract=item.text,
                url=item.link,
                published_at=stories._aware(item.published_at),
                source=stories._source(item.source, set()),
                paper_id=arxiv_id,
                version=version,
                matched_terms=terms,
            )
        )
    return ResearchOut(papers=papers)


class SuggestIn(Strict):
    keywords: Annotated[list[Term], Field(min_length=1, max_length=MAX_TERMS)]


@router.post("/me/interests/suggest")
def suggest_interest(body: SuggestIn, reader: Reader, kit: Kit) -> interest_agent.Suggestions:
    """Related terms, categories and rule-3 flags for keywords being edited. Nothing is
    stored; the decision log keeps the run without the keywords."""
    if not _within_limit(f"suggest:{reader.id}", SUGGEST_LIMIT):
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Too many suggestions; try again in a few minutes.")
    try:
        return interest_agent.suggest(kit, body.keywords)
    except interest_agent.InterestAgentUnavailable:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Suggestions are unavailable right now.")
