"""Agent prompts are files, versioned with the code (AGENTS.md §4). Each starts with a
`version:` line and a `---`; the version goes into the decision log and onto every
fact the agent produces."""

from dataclasses import dataclass
from functools import cache
from pathlib import Path

_DIR = Path(__file__).parent


@dataclass(frozen=True)
class Prompt:
    version: str
    text: str


@cache
def load(name: str) -> Prompt:
    header, _, body = (_DIR / f"{name}.md").read_text(encoding="utf-8").partition("\n---\n")
    version = header.strip().removeprefix("version:").strip()
    if not version or not body.strip():
        raise ValueError(f"prompt {name!r} needs a 'version:' line and a body")
    return Prompt(version=version, text=body.strip())
