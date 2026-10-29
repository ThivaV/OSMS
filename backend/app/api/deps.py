"""Request dependencies: a database session, and the signed-in reader."""

from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.auth.tokens import AuthUnavailable, InvalidToken
from app.db.models import User
from app.services import accounts


def db_session(request: Request) -> Iterator[Session]:
    with request.app.state.sessions() as session:
        yield session


Db = Annotated[Session, Depends(db_session)]


def current_reader(request: Request, db: Db) -> User:
    scheme, _, token = request.headers.get("authorization", "").partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sign in first.", {"WWW-Authenticate": "Bearer"})
    try:
        claims = request.app.state.verifier.verify(token.strip())
    except InvalidToken:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sign in again.", {"WWW-Authenticate": "Bearer"})
    except AuthUnavailable:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Sign-in is unavailable right now.")
    return accounts.reader_for(db, claims)


Reader = Annotated[User, Depends(current_reader)]
