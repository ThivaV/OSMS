"""FastAPI application entry point: `uvicorn app.main:app` (or `make api`)."""

import secrets
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import briefings, me, stories
from app.auth.tokens import JwksKeys, TokenVerifier
from app.clients.openai_compat import models_from_settings
from app.config import SEED_OPML, Settings, check_routes
from app.db.sqlite import make_engine, migrate, session_factory
from app.services.ingestion.opml import load_seed


def create_app(settings: Settings | None = None, verifier: TokenVerifier | None = None, models=None) -> FastAPI:
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
        # The agents the API runs itself (ask this story): the same routing table as the worker.
        app.state.models = models or models_from_settings(settings)
        # Briefing audio URLs are signed with a key that lives as long as this process.
        app.state.audio_key = secrets.token_bytes(32)
        app.state.briefings_dir = settings.briefings_dir
        app.state.visuals_dir = settings.visuals_dir
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
    app.include_router(briefings.router)
    return app


app = create_app()
