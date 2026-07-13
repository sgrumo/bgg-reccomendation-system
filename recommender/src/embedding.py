"""Shared embedding model and text construction for semantic search.

The embedding text must be built identically at backfill time and query time,
so both paths import :func:`build_embedding_text` from here.
"""

import json
from functools import lru_cache
from typing import Any

from fastembed import TextEmbedding

MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
EMBEDDING_DIM = 384

# MiniLM truncates at its own token limit; this only guards against a few
# pathological descriptions inflating per-batch memory.
_MAX_DESCRIPTION_CHARS = 2000


@lru_cache(maxsize=1)
def get_model() -> TextEmbedding:
    """Load the embedding model once. Weights download on first call."""
    return TextEmbedding(MODEL_NAME)


def _labels(items: Any) -> list[str]:
    if isinstance(items, str):
        try:
            items = json.loads(items)
        except json.JSONDecodeError:
            return []
    if not items:
        return []
    return [str(i["value"]) for i in items if isinstance(i, dict) and i.get("value")]


def build_embedding_text(
    name: str | None,
    description: str | None,
    categories: Any,
    mechanics: Any,
) -> str:
    """Build the text embedded for a game, identical at backfill and query time."""
    parts: list[str] = []
    if name:
        parts.append(f"{name}.")
    if description:
        parts.append(description[:_MAX_DESCRIPTION_CHARS])
    cats = _labels(categories)
    if cats:
        parts.append(f"Categories: {', '.join(cats)}.")
    mechs = _labels(mechanics)
    if mechs:
        parts.append(f"Mechanics: {', '.join(mechs)}.")
    return " ".join(parts)


def embed_texts(texts: list[str]) -> list[list[float]]:
    """Embed a batch of texts into 384-dim vectors."""
    return [vec.tolist() for vec in get_model().embed(texts)]


def to_pgvector(vec: list[float]) -> str:
    """Format a vector as the literal pgvector expects behind a ``::vector`` cast."""
    return "[" + ",".join(repr(x) for x in vec) + "]"
