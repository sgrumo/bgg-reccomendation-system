"""Recommendation engine — orchestrates data loading, feature building, and similarity."""

import numpy as np
import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity as cosine_sim
from sqlalchemy.engine import Engine

from src.db import load_board_games
from src.features import build_feature_matrix
from src.preprocess import preprocess
from src.similarity import compute_similarity_matrix, find_similar, _base_name, _game_families


class RecommendationEngine:
    """Loads board game data, builds features, and serves recommendations."""

    def __init__(self, db_engine: Engine) -> None:
        self._db_engine = db_engine
        self._df: pd.DataFrame | None = None
        self._features: pd.DataFrame | None = None
        self._similarity_matrix: np.ndarray | None = None

    def load(self, min_ratings: int = 30) -> None:
        """Load data from the database, preprocess, and build similarity matrix."""
        raw = load_board_games(self._db_engine)

        if raw.empty:
            self._df = raw
            self._features = None
            self._similarity_matrix = None
            return

        processed = preprocess(raw, min_ratings=min_ratings)

        if processed.empty:
            self._df = processed
            self._features = None
            self._similarity_matrix = None
            return

        self._df = processed
        self._features = build_feature_matrix(self._df)
        self._similarity_matrix = compute_similarity_matrix(self._features)

    @property
    def is_loaded(self) -> bool:
        return self._df is not None

    @property
    def game_count(self) -> int:
        if self._df is None:
            return 0
        return len(self._df)

    @property
    def df(self) -> pd.DataFrame:
        if self._df is None:
            raise RuntimeError("Engine not loaded. Call load() first.")
        return self._df

    def recommend(
        self, bgg_id: int, top_n: int = 10
    ) -> list[dict[str, float | int | str]]:
        """Get top N similar games for a given BGG ID."""
        if self._df is None or self._similarity_matrix is None:
            raise RuntimeError("Engine not loaded. Call load() first.")

        return find_similar(bgg_id, self._similarity_matrix, self._df, top_n)

    def recommend_for_user(
        self,
        ratings: dict[int, float],
        top_n: int = 20,
    ) -> list[dict[str, float | int | str]]:
        """Recommend games based on a user's rated games.

        Args:
            ratings: dict mapping bgg_id to user rating (1-10).
            top_n: number of recommendations to return.

        The user profile is a weighted average of feature vectors,
        where weights are the normalized user ratings.
        """
        if self._df is None or self._features is None:
            raise RuntimeError("Engine not loaded. Call load() first.")

        # Map bgg_ids to DataFrame indices
        rated_indices: list[int] = []
        weights: list[float] = []
        rated_bgg_ids: set[int] = set()

        for bgg_id, rating in ratings.items():
            idx = self._df.index[self._df["bgg_id"] == bgg_id]
            if len(idx) > 0:
                rated_indices.append(idx[0])
                weights.append(rating)
                rated_bgg_ids.add(bgg_id)

        if not rated_indices:
            return []

        # Build user profile: weighted average of feature vectors
        weight_array = np.array(weights)
        weight_array = weight_array / weight_array.sum()

        feature_vectors = self._features.iloc[rated_indices].values
        user_profile = np.average(feature_vectors, axis=0, weights=weight_array)
        user_profile = user_profile.reshape(1, -1)

        # Compute similarity between user profile and all games
        scores = cosine_sim(user_profile, self._features.values).flatten()

        # Collect families and base names from rated games to exclude editions
        seen_families: set[str] = set()
        seen_base_names: set[str] = set()
        for i in rated_indices:
            seen_families.update(_game_families(self._df.iloc[i]["families"]))
            seen_base_names.add(_base_name(str(self._df.iloc[i]["name"])))

        # Rank and filter
        ranked_indices = np.argsort(scores)[::-1]
        results: list[dict[str, float | int | str]] = []

        for i in ranked_indices:
            candidate_bgg_id = int(self._df.iloc[i]["bgg_id"])

            # Skip games the user already rated
            if candidate_bgg_id in rated_bgg_ids:
                continue

            candidate_families = _game_families(self._df.iloc[i]["families"])
            candidate_name = str(self._df.iloc[i]["name"])
            candidate_base = _base_name(candidate_name)

            # Skip if shares a "Game: X" family with rated or already-included game
            if candidate_families and seen_families & candidate_families:
                continue

            # Skip if base name matches rated or already-included game
            if candidate_base in seen_base_names:
                continue

            results.append({
                "bgg_id": candidate_bgg_id,
                "name": candidate_name,
                "score": float(scores[i]),
            })
            seen_families.update(candidate_families)
            seen_base_names.add(candidate_base)

            if len(results) >= top_n:
                break

        return results

    def search(self, query: str, limit: int = 20) -> list[dict[str, int | str]]:
        """Search games by name substring."""
        if self._df is None:
            raise RuntimeError("Engine not loaded. Call load() first.")

        mask = self._df["name"].str.contains(query, case=False, na=False)
        matches = self._df[mask].head(limit)

        return [
            {"bgg_id": int(row["bgg_id"]), "name": str(row["name"])}
            for _, row in matches.iterrows()
        ]
