"""Recommendation engine — orchestrates data loading, feature building, and similarity."""

import numpy as np
import pandas as pd
from sqlalchemy.engine import Engine

from src.db import load_board_games
from src.features import build_feature_matrix
from src.similarity import compute_similarity_matrix, find_similar


class RecommendationEngine:
    """Loads board game data, builds features, and serves recommendations."""

    def __init__(self, db_engine: Engine) -> None:
        self._db_engine = db_engine
        self._df: pd.DataFrame | None = None
        self._similarity_matrix: np.ndarray | None = None

    def load(self) -> None:
        """Load data from the database and precompute the similarity matrix."""
        self._df = load_board_games(self._db_engine)
        features = build_feature_matrix(self._df)
        self._similarity_matrix = compute_similarity_matrix(features)

    @property
    def is_loaded(self) -> bool:
        return self._df is not None and self._similarity_matrix is not None

    @property
    def game_count(self) -> int:
        if self._df is None:
            return 0
        return len(self._df)

    def recommend(
        self, bgg_id: int, top_n: int = 10
    ) -> list[dict[str, float | int | str]]:
        """Get top N similar games for a given BGG ID."""
        if self._df is None or self._similarity_matrix is None:
            raise RuntimeError("Engine not loaded. Call load() first.")

        return find_similar(bgg_id, self._similarity_matrix, self._df, top_n)

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
