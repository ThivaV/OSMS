"""Settings read from environment variables (names in .env.example). The model routing
table (for each agent: model id, endpoint, backup) joins here with the agents."""

from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
SEED_OPML = BACKEND_DIR / "seed" / "sources.opml"


class Settings(BaseSettings):
    # Blank values copied from .env.example count as unset.
    model_config = SettingsConfigDict(env_file=REPO_ROOT / ".env", env_ignore_empty=True, extra="ignore")

    database_url: str = f"sqlite:///{REPO_ROOT / 'data' / 'osms.db'}"

    # The Better Auth service: it signs the API tokens and publishes their keys.
    auth_url: str = Field("http://localhost:3000", validation_alias="BETTER_AUTH_URL")
    api_audience: str = Field("osms-api", validation_alias="OSMS_API_AUDIENCE")

    # The app's origins (Flutter web), comma-separated.
    app_origins: str = Field("http://localhost:8080", validation_alias="OSMS_APP_ORIGINS")

    @property
    def jwks_url(self) -> str:
        return f"{self.auth_url}/api/auth/jwks"

    @property
    def origins(self) -> list[str]:
        return [o.strip() for o in self.app_origins.split(",") if o.strip()]
