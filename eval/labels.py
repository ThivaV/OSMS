"""Hand-labelled story groups: ids + links only, never full text (rule 5).

Every ``eval/labels/*.json`` file looks like::

    {"version": 1, "groups": [{"id": "g1", "items": [{"id": "a1", "link": "https://…"}]}]}

`load_labels` parses a directory of them and refuses anything fuller.
"""

from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import urlparse

LABEL_VERSION = 1

#: Keys that would mean full text crept into the labels. Refused on sight.
TEXT_KEYS = frozenset({"text", "transcript", "body", "content", "summary"})


class LabelError(ValueError):
    """A labels file breaks the format. Fix the file, not the loader."""


def load_labels(directory: str | Path) -> list[frozenset[str]]:
    """All story groups across every ``*.json`` file: each a set of item ids."""
    directory = Path(directory)
    files = sorted(directory.glob("*.json"))
    groups: list[frozenset[str]] = []
    seen: dict[str, Path] = {}
    for path in files:
        try:
            document = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise LabelError(f"{path.name}: not readable JSON ({error})") from error
        groups.extend(_load_file(path, document, seen))
    return groups


def _load_file(path: Path, document: object, seen: dict[str, Path]) -> list[frozenset[str]]:
    if not isinstance(document, dict) or document.get("version") != LABEL_VERSION:
        raise LabelError(f"{path.name}: want {{\"version\": {LABEL_VERSION}, \"groups\": [...]}}")
    raw_groups = document.get("groups")
    if not isinstance(raw_groups, list) or not raw_groups:
        raise LabelError(f"{path.name}: at least one group")
    groups: list[frozenset[str]] = []
    for position, raw in enumerate(raw_groups):
        if not isinstance(raw, dict) or not isinstance(raw.get("items"), list) or not raw["items"]:
            raise LabelError(f"{path.name}: group #{position} needs a non-empty items list")
        if TEXT_KEYS & raw.keys():
            raise LabelError(f"{path.name}: group #{position} carries text, ids + links only")
        members: set[str] = set()
        for item in raw["items"]:
            if not isinstance(item, dict):
                raise LabelError(f"{path.name}: group #{position} has a non-object item")
            if TEXT_KEYS & item.keys():
                raise LabelError(f"{path.name}: item {item.get('id', '?')!r} carries text, ids + links only")
            item_id, link = item.get("id"), item.get("link")
            if not isinstance(item_id, str) or not item_id.strip():
                raise LabelError(f"{path.name}: group #{position} has an item without an id")
            if not isinstance(link, str) or urlparse(link).scheme not in ("http", "https"):
                raise LabelError(f"{path.name}: item {item_id!r} needs an http(s) link")
            if item_id in seen:
                raise LabelError(f"{path.name}: item {item_id!r} already labelled in {seen[item_id].name}")
            seen[item_id] = path
            members.add(item_id)
        groups.append(frozenset(members))
    return groups
