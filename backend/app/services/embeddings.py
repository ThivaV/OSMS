"""BGE-M3 embeddings: one dense and one sparse vector per item, so a Danish and an English
article about the same event land close together (dense) and shared names still count
(sparse). The model is an optional install (`uv sync --extra models`, about 3 GB with
its weights); tests and CI use `HashEmbedder`, which needs nothing."""

import hashlib
import math
import re
from dataclasses import dataclass
from typing import Protocol

DIM = 1024
MAX_TOKENS = 512


@dataclass(frozen=True)
class Embedding:
    dense: list[float]
    sparse: dict[int, float]


class Embedder(Protocol):
    dim: int

    def embed(self, texts: list[str]) -> list[Embedding]: ...


def item_text(title: str, text: str) -> str:
    """What an item is embedded as: its headline and the start of its excerpt."""
    return f"{title}\n{text[:1500]}".strip()


class BgeM3Embedder:
    """BAAI/bge-m3 through FlagEmbedding, loaded on first use (on the Mac's GPU if any)."""

    dim = DIM

    def __init__(self, model: str = "BAAI/bge-m3", batch_size: int = 16) -> None:
        self.model_name = model
        self.batch_size = batch_size
        self._model = None

    def _load(self):
        if self._model is None:
            try:
                import torch
                from FlagEmbedding import BGEM3FlagModel
            except ImportError as error:  # pragma: no cover - depends on the optional install
                raise RuntimeError("BGE-M3 isn't installed: run `uv sync --extra models` in backend/") from error
            device = "mps" if torch.backends.mps.is_available() else ("cuda" if torch.cuda.is_available() else "cpu")
            self._model = BGEM3FlagModel(self.model_name, use_fp16=device != "cpu", devices=device)
        return self._model

    def embed(self, texts: list[str]) -> list[Embedding]:
        if not texts:
            return []
        out = self._load().encode(
            texts, batch_size=self.batch_size, max_length=MAX_TOKENS, return_dense=True, return_sparse=True
        )
        return [
            Embedding(
                dense=[float(x) for x in dense],
                sparse={int(token): float(weight) for token, weight in weights.items() if float(weight) > 0},
            )
            for dense, weights in zip(out["dense_vecs"], out["lexical_weights"])
        ]


_WORDS = re.compile(r"\w+", re.UNICODE)


class HashEmbedder:
    """Deterministic stand-in for tests: shared words make vectors close. Never real."""

    def __init__(self, dim: int = 64) -> None:
        self.dim = dim

    def embed(self, texts: list[str]) -> list[Embedding]:
        result = []
        for text in texts:
            dense = [0.0] * self.dim
            sparse: dict[int, float] = {}
            for word in _WORDS.findall(text.lower()):
                h = int(hashlib.sha256(word.encode()).hexdigest(), 16)
                dense[h % self.dim] += 1.0
                sparse[h % 250_000] = sparse.get(h % 250_000, 0.0) + 1.0
            norm = math.sqrt(sum(x * x for x in dense)) or 1.0
            result.append(Embedding([x / norm for x in dense], sparse))
        return result


def cosine(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a)) or 1.0
    nb = math.sqrt(sum(y * y for y in b)) or 1.0
    return dot / (na * nb)
