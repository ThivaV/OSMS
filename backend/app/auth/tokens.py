"""API tokens: short-lived JWTs the Better Auth service signs (EdDSA) and publishes
the keys for at /api/auth/jwks. The reader's id is the token's `sub`, never anything
the request says about itself."""

from dataclasses import dataclass
from typing import Any, Protocol

import jwt

# Pinned: a token signed any other way (or not at all) is refused.
ALGORITHMS = ["EdDSA"]


class InvalidToken(Exception):
    """The token is missing, malformed, expired, or not ours."""


class AuthUnavailable(Exception):
    """The signing keys can't be fetched right now."""


@dataclass(frozen=True)
class Claims:
    user_id: str
    email: str
    name: str


class KeySource(Protocol):
    def key_for(self, token: str) -> Any: ...


class JwksKeys:
    """Keys from the auth service's JWKS, cached, refetched when a new `kid` appears."""

    def __init__(self, url: str) -> None:
        self._client = jwt.PyJWKClient(url, cache_keys=True, lifespan=3600, timeout=5)

    def key_for(self, token: str) -> Any:
        try:
            return self._client.get_signing_key_from_jwt(token).key
        except jwt.PyJWKClientConnectionError as error:
            raise AuthUnavailable from error
        except jwt.PyJWTError as error:
            raise InvalidToken from error


class TokenVerifier:
    def __init__(self, *, issuer: str, audience: str, keys: KeySource) -> None:
        self._issuer, self._audience, self._keys = issuer, audience, keys

    def verify(self, token: str) -> Claims:
        try:
            claims = jwt.decode(
                token,
                self._keys.key_for(token),
                algorithms=ALGORITHMS,
                audience=self._audience,
                issuer=self._issuer,
                leeway=30,
                options={"require": ["exp", "iat", "iss", "aud", "sub"]},
            )
        except jwt.PyJWTError as error:
            raise InvalidToken from error
        email = claims.get("email")
        if not isinstance(email, str) or "@" not in email:
            raise InvalidToken("no email in token")
        return Claims(user_id=str(claims["sub"]), email=email, name=str(claims.get("name") or ""))
