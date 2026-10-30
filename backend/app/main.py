"""FastAPI application entry point: `uvicorn app.main:app` (or `make api`)."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import me, stories
from app.auth.tokens import JwksKeys, TokenVerifier
from app.config import SEED_OPML, Settings, check_routes
from app.db.sqlite import make_engine, migrate, session_factory
from app.services.ingestion.opml import load_seed


def create_app(settings: Settings | None = None, verifier: TokenVerifier | None = None) -> FastAPI:
    settings = settings or Settings()
    # A misconfigured routing table fails here, before any agent decides anything.
    check_routes(settings.model_routes())

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        migrate(settings.database_url)
        engine = make_engine(settings.database_url)
        app.state.sessions = session_factory(engine)
        with app.state.sessions() as db:
            load_seed(db, SEED_OPML)
        app.state.verifier = verifier or TokenVerifier(
            issuer=settings.auth_url, audience=settings.api_audience, keys=JwksKeys(settings.jwks_url)
        )
        yield
        engine.dispose()

    app = FastAPI(title="OSMS API", version="0.1.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.origins,
        # POST: marking a story read, and Day 8's `POST /stories/{id}/ask`.
        allow_methods=["GET", "PUT", "PATCH", "DELETE", "POST"],
        allow_headers=["Authorization", "Content-Type"],
    )

    @app.get("/health")
    def health() -> dict[str, bool]:
        return {"ok": True}

    app.include_router(me.router)
    app.include_router(stories.router)
    return app


app = create_app()
