"""Similarity computation between board games."""

import numpy as np
import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity

from src.preprocess import extract_label_list


def compute_similarity_matrix(feature_matrix: pd.DataFrame) -> np.ndarray:
    """Compute pairwise cosine similarity between all games."""
    return cosine_similarity(feature_matrix)


def find_similar(
    bgg_id: int,
    similarity_matrix: np.ndarray,
    df: pd.DataFrame,
    top_n: int = 10,
) -> list[dict[str, float | int | str]]:
    """Find the most similar games to a given game.

    Filters out other editions/versions of the same game
    using the BGG "Game: X" family tag.

    Returns a list of dicts with bgg_id, name, and similarity score.
    """
    idx = df.index[df["bgg_id"] == bgg_id]
    if len(idx) == 0:
        return []

    idx = idx[0]
    source_families = _game_families(df.iloc[idx]["families"])
    scores = similarity_matrix[idx]
    ranked_indices = np.argsort(scores)[::-1]

    results: list[dict[str, float | int | str]] = []
    for i in ranked_indices:
        if i == idx:
            continue
        if _is_same_game(df.iloc[i]["families"], source_families):
            continue

        results.append({
            "bgg_id": int(df.iloc[i]["bgg_id"]),
            "name": str(df.iloc[i]["name"]),
            "score": float(scores[i]),
        })

        if len(results) >= top_n:
            break

    return results


def _game_families(families_raw: list[dict] | str | None) -> set[str]:
    """Extract 'Game: X' family names from a game's families field."""
    labels = extract_label_list(families_raw)
    return {label for label in labels if label.startswith("Game: ")}


def _is_same_game(
    candidate_families_raw: list[dict] | str | None,
    source_families: set[str],
) -> bool:
    """Check if a candidate game shares a 'Game: X' family with the source."""
    if not source_families:
        return False
    candidate_families = _game_families(candidate_families_raw)
    return bool(source_families & candidate_families)
