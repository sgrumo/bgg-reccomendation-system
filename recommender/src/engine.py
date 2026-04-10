"""Recommendation engine — orchestrates data loading, feature building, and similarity."""

import numpy as np
import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity as cosine_sim
from sqlalchemy.engine import Engine

from src.db import load_board_games
from src.features import build_feature_matrix
from src.preprocess import preprocess, extract_label_list
from src.similarity import compute_similarity_matrix, find_similar


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
        self._df = preprocess(raw, min_ratings=min_ratings)
        self._features = build_feature_matrix(self._df)
        self._similarity_matrix = compute_similarity_matrix(self._features)

    @property
    def is_loaded(self) -> bool:
        return self._df is not None and self._similarity_matrix is not None

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

        # Collect "Game: X" families from all rated games to exclude editions
        rated_families: set[str] = set()
        for i in rated_indices:
            families = extract_label_list(self._df.iloc[i]["families"])
            rated_families.update(f for f in families if f.startswith("Game: "))

        # Rank and filter
        ranked_indices = np.argsort(scores)[::-1]
        results: list[dict[str, float | int | str]] = []

        for i in ranked_indices:
            candidate_bgg_id = int(self._df.iloc[i]["bgg_id"])

            # Skip games the user already rated
            if candidate_bgg_id in rated_bgg_ids:
                continue

            # Skip editions/versions of rated games
            if rated_families:
                candidate_families = extract_label_list(self._df.iloc[i]["families"])
                candidate_game_families = {
                    f for f in candidate_families if f.startswith("Game: ")
                }
                if rated_families & candidate_game_families:
                    continue

            results.append({
                "bgg_id": candidate_bgg_id,
                "name": str(self._df.iloc[i]["name"]),
                "score": float(scores[i]),
            })

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
