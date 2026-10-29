"""Only tokens the auth service signed, for this API, still valid, name a reader."""

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from fastapi.testclient import TestClient

from app.auth.tokens import AuthUnavailable, TokenVerifier
from app.config import Settings
from app.main import create_app
from tests.conftest import AUDIENCE, ISSUER, sign


def test_health(client: TestClient) -> None:
    assert client.get("/health").json() == {"ok": True}


@pytest.mark.parametrize(
    "header",
    [
        None,
        "Bearer",
        "Basic abc",
        "Bearer not-a-token",
        f"Bearer {sign('ada', audience='someone-else')}",
        f"Bearer {sign('ada', issuer='https://evil.example')}",
        f"Bearer {sign('ada', lifetime=-120)}",
        f"Bearer {sign('ada', key=Ed25519PrivateKey.generate())}",
        # Algorithm confusion: an HMAC token must never pass as ours.
        f"Bearer {sign('ada', key='a-shared-secret-of-at-least-32-bytes!', algorithm='HS256')}",
        f"Bearer {jwt.encode({'sub': 'ada', 'iss': ISSUER, 'aud': AUDIENCE}, None, algorithm='none')}",
    ],
)
def test_refuses_anything_but_a_valid_token(client: TestClient, header: str | None) -> None:
    response = client.get("/me", headers={"Authorization": header} if header else {})
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_first_sign_in_creates_the_reader(client: TestClient, auth) -> None:
    me = client.get("/me", headers=auth("ada")).json()
    assert me["id"] == "ada"
    assert me["email"] == "ada@users.example"
    assert me["onboarded"] is False
    assert me["topics"] == me["subscriptions"] == me["interests"] == []


def test_profile_follows_the_sign_in_account(client: TestClient) -> None:
    client.get("/me", headers={"Authorization": f"Bearer {sign('ada', name='Ada')}"})
    renamed = client.get("/me", headers={"Authorization": f"Bearer {sign('ada', 'ada@new.example', name='Ada L')}"})
    assert renamed.json()["email"] == "ada@new.example"
    assert renamed.json()["display_name"] == "Ada L"


class Down:
    def key_for(self, token: str):
        raise AuthUnavailable


def test_says_so_when_sign_in_is_down(settings: Settings) -> None:
    verifier = TokenVerifier(issuer=ISSUER, audience=AUDIENCE, keys=Down())
    with TestClient(create_app(settings, verifier)) as client:
        assert client.get("/me", headers={"Authorization": f"Bearer {sign('ada')}"}).status_code == 503


def test_cors_answers_the_app_only(client: TestClient) -> None:
    preflight = {"Access-Control-Request-Method": "GET", "Access-Control-Request-Headers": "authorization"}
    ok = client.options("/me", headers={"Origin": "http://localhost:8080", **preflight})
    assert ok.headers["access-control-allow-origin"] == "http://localhost:8080"
    other = client.options("/me", headers={"Origin": "https://evil.example", **preflight})
    assert "access-control-allow-origin" not in other.headers
