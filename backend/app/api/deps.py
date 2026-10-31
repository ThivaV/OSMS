"""Request dependencies: a database session, the signed-in reader, and the agents."""

from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.agent.decision_log import DecisionLog
from app.agent.kit import AgentKit
from app.agent.runtime import Runner
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


def agent_kit(request: Request) -> Iterator[AgentKit]:
    """The agents for one request; the decision log commits on its own session."""
    models = request.app.state.models
    with request.app.state.sessions() as log_db:
        yield AgentKit(
            runner=Runner(models, DecisionLog(log_db)),
            routes=dict(models.routes),
            available={agent: models.available(agent) for agent in models.routes},
        )


Kit = Annotated[AgentKit, Depends(agent_kit)]
