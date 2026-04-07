"""Similarity computation between board games."""

import numpy as np
import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity


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

    Returns a list of dicts with bgg_id, name, and similarity score.
    """
    idx = df.index[df["bgg_id"] == bgg_id]
    if len(idx) == 0:
        return []

    idx = idx[0]
    scores = similarity_matrix[idx]
    similar_indices = np.argsort(scores)[::-1][1 : top_n + 1]

    results: list[dict[str, float | int | str]] = []
    for i in similar_indices:
        results.append({
            "bgg_id": int(df.iloc[i]["bgg_id"]),
            "name": str(df.iloc[i]["name"]),
            "score": float(scores[i]),
        })

    return results
