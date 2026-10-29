"""Test helpers: a throwaway database, and API tokens signed with a test key the way
the Better Auth service signs them (EdDSA, issuer, audience, 15 minutes)."""

import time
from collections.abc import Callable, Iterator
from typing import Any

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from fastapi.testclient import TestClient

from app.auth.tokens import TokenVerifier
from app.config import Settings
from app.main import create_app

ISSUER = "http://localhost:3000"
AUDIENCE = "osms-api"
KEY = Ed25519PrivateKey.generate()


class StaticKeys:
    def __init__(self, key: Any) -> None:
        self.key = key

    def key_for(self, token: str) -> Any:
        return self.key


def sign(
    sub: str,
    email: str | None = None,
    *,
    name: str = "Test Reader",
    key: Any = KEY,
    algorithm: str = "EdDSA",
    issuer: str = ISSUER,
    audience: str = AUDIENCE,
    lifetime: int = 900,
) -> str:
    now = int(time.time())
    claims = {"sub": sub, "email": email or f"{sub}@users.example", "name": name}
    claims |= {"iss": issuer, "aud": audience, "iat": now, "exp": now + lifetime}
    return jwt.encode(claims, key, algorithm=algorithm, headers={"kid": "test"})


Auth = Callable[[str], dict[str, str]]


@pytest.fixture
def settings(tmp_path) -> Settings:
    return Settings(database_url=f"sqlite:///{tmp_path / 'osms.db'}")


@pytest.fixture
def client(settings: Settings) -> Iterator[TestClient]:
    verifier = TokenVerifier(issuer=ISSUER, audience=AUDIENCE, keys=StaticKeys(KEY.public_key()))
    with TestClient(create_app(settings, verifier)) as test_client:
        yield test_client


@pytest.fixture
def auth() -> Auth:
    return lambda sub: {"Authorization": f"Bearer {sign(sub)}"}
