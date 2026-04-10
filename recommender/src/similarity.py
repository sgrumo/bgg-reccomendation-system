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
    using the BGG "Game: X" family tag and name similarity.

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
    seen_families: set[str] = set(source_families)
    seen_base_names: set[str] = {_base_name(str(df.iloc[idx]["name"]))}

    for i in ranked_indices:
        if i == idx:
            continue

        candidate_families = _game_families(df.iloc[i]["families"])
        candidate_name = str(df.iloc[i]["name"])
        candidate_base = _base_name(candidate_name)

        # Skip if shares a "Game: X" family with source or any already-included game
        if candidate_families and seen_families & candidate_families:
            continue

        # Skip if base name matches source or any already-included game
        if candidate_base in seen_base_names:
            continue

        results.append({
            "bgg_id": int(df.iloc[i]["bgg_id"]),
            "name": candidate_name,
            "score": float(scores[i]),
        })
        seen_families.update(candidate_families)
        seen_base_names.add(candidate_base)

        if len(results) >= top_n:
            break

    return results


def _base_name(name: str) -> str:
    """Extract base game name by stripping edition/version suffixes."""
    separators = [":", " – ", " - ", " ("]
    lower = name.lower().strip()
    for sep in separators:
        pos = lower.find(sep)
        if pos > 0:
            lower = lower[:pos]
    return lower.strip()


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
