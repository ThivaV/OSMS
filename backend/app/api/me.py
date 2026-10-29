"""The signed-in reader: profile, onboarding picks, research interests, settings and
"Delete my account". Every route acts on the reader the token names, and only them."""

from fastapi import APIRouter, HTTPException, Response, status

from app.api.deps import Db, Reader
from app.schemas.account import InterestsIn, MeOut, OnboardingIn, OnboardingOptions, SettingsIn
from app.services import accounts

router = APIRouter()


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
def delete_me(reader: Reader, db: Db) -> Response:
    """Deletes the reader's OSMS data. The app then deletes the sign-in account itself."""
    accounts.delete_reader(db, reader)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
