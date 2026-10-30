"""Settings read from environment variables (names in .env.example). The model routing
table (for each agent: model id, endpoint, backup) joins here with the agents."""

from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.agent.guardrails import ALL_AGENTS
from app.agent.runtime import ModelRoute

BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
SEED_OPML = BACKEND_DIR / "seed" / "sources.opml"

# Pinned model ids (AGENTS.md §3). Never from the environment.
SPARK_ID = "muse-spark-1.3"
SPARK_OPEN_ID = "muse-spark-open-1026"
WONDER_ID = "muse-wonder-1.0"
# Provisional Ollama tag: confirm against the Ollama/Fireworks docs when the
# triage agent lands (Day 7). The route shape is what's tested, not this tag.
GLIMMER_MODEL = "muse-glimmer-30b"

# One base URL for hosted Meta models (AGENTS.md §3).
META_API_URL = "https://api.meta.ai/v1"


class Settings(BaseSettings):
    # Blank values copied from .env.example count as unset.
    model_config = SettingsConfigDict(env_file=REPO_ROOT / ".env", env_ignore_empty=True, extra="ignore")

    database_url: str = f"sqlite:///{REPO_ROOT / 'data' / 'osms.db'}"

    # The Better Auth service: it signs the API tokens and publishes their keys.
    auth_url: str = Field("http://localhost:3000", validation_alias="BETTER_AUTH_URL")
    api_audience: str = Field("osms-api", validation_alias="OSMS_API_AUDIENCE")

    # The app's origins (Flutter web), comma-separated.
    app_origins: str = Field("http://localhost:8080", validation_alias="OSMS_APP_ORIGINS")

    # Where the text models live. Meta's base URL is pinned above; Baseten's
    # deployment URL varies, so it comes from the environment. Empty until Day 5
    # wires the client, which refuses to judge without it — startup stays green.
    glimmer_base_url: str = Field("http://127.0.0.1:11434", validation_alias="GLIMMER_BASE_URL")
    baseten_base_url: str = Field("", validation_alias="BASETEN_BASE_URL")

    @property
    def jwks_url(self) -> str:
        return f"{self.auth_url}/api/auth/jwks"

    @property
    def origins(self) -> list[str]:
        return [o.strip() for o in self.app_origins.split(",") if o.strip()]

    def model_routes(self) -> dict[str, ModelRoute]:
        """Every agent → its model, endpoint and backup. Switching the editor
        to Muse Wonder, or failing over, is configuration, not code. Only
        public-source-text agents get a backup (guardrails); the triage agent
        escalates unsure items to Muse Spark inside the same provider."""
        spark = ModelRoute(model=SPARK_ID, endpoint=META_API_URL)
        return {
            "triage": ModelRoute(model=GLIMMER_MODEL, endpoint=self.glimmer_base_url, effort="low"),
            "interest": spark,
            "judge": ModelRoute(
                model=SPARK_OPEN_ID, endpoint=self.baseten_base_url, backup=SPARK_ID, effort="medium"
            ),
            "claims": ModelRoute(model=SPARK_ID, endpoint=META_API_URL, backup=SPARK_OPEN_ID, effort="medium"),
            "verifier": ModelRoute(model=SPARK_ID, endpoint=META_API_URL, backup=SPARK_OPEN_ID, effort="high"),
            "editor": ModelRoute(model=SPARK_ID, endpoint=META_API_URL, effort="high"),
            "writer": spark,
            "ask": spark,
        }

def check_routes(routes: dict[str, ModelRoute]) -> None:
    """The routing table upholds the frozen backup rules. Run at startup and
    in tests: a misconfigured agent must fail before it decides anything."""
    missing = ALL_AGENTS - routes.keys()
    if missing:
        raise ValueError(f"agents without a route: {sorted(missing)}")
    for agent, route in routes.items():
        if "-contributor" in route.model or (route.backup and "-contributor" in route.backup):
            raise ValueError(f"{agent}: contributor variants never run on reader paths")
        has_backup = route.backup is not None
        if has_backup and agent not in {"judge", "claims", "verifier"}:
            raise ValueError(f"{agent}: backups never move personal data")
        if agent in {"judge", "claims", "verifier"} and route.backup is None:
            raise ValueError(f"{agent}: needs its specified backup")
