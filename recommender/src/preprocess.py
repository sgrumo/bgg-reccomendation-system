"""Data cleaning and preprocessing for board game data."""

import json

import pandas as pd
import numpy as np


def clean_outliers(df: pd.DataFrame) -> pd.DataFrame:
    """Remove or cap rows with clearly invalid data."""
    cleaned = df.copy()

    # Cap absurd values
    cleaned["min_players"] = cleaned["min_players"].clip(upper=20)
    cleaned["max_players"] = cleaned["max_players"].clip(upper=100)
    cleaned["min_playtime"] = cleaned["min_playtime"].clip(upper=1440)
    cleaned["max_playtime"] = cleaned["max_playtime"].clip(upper=1440)
    cleaned["playing_time"] = cleaned["playing_time"].clip(upper=1440)
    cleaned["min_age"] = cleaned["min_age"].clip(upper=21)

    # Drop games published before 1900 (ancient/novelty entries)
    cleaned = cleaned[cleaned["year_published"] >= 1900]

    return cleaned.reset_index(drop=True)


def filter_min_ratings(df: pd.DataFrame, min_ratings: int = 30) -> pd.DataFrame:
    """Keep only games with enough ratings to be meaningful."""
    return df[df["users_rated"] >= min_ratings].reset_index(drop=True)


def fill_missing(df: pd.DataFrame) -> pd.DataFrame:
    """Fill missing numeric values with sensible defaults."""
    filled = df.copy()

    numeric_defaults: dict[str, float] = {
        "min_players": 2.0,
        "max_players": 4.0,
        "min_playtime": 30.0,
        "max_playtime": 60.0,
        "playing_time": 45.0,
        "min_age": 10.0,
        "average_weight": 0.0,
        "average_rating": 0.0,
        "bayes_average_rating": 0.0,
    }

    for col, default in numeric_defaults.items():
        if col in filled.columns:
            filled[col] = filled[col].fillna(default)

    return filled


def extract_label_list(raw: list[dict] | str | None) -> list[str]:
    """Extract label values from a JSON array of {id, value} objects."""
    if raw is None:
        return []
    if isinstance(raw, str):
        raw = json.loads(raw)
    return [
        item.get("value") or item.get("name")
        for item in raw
        if item.get("value") or item.get("name")
    ]


def add_derived_features(df: pd.DataFrame) -> pd.DataFrame:
    """Add computed columns useful for analysis and modeling."""
    enriched = df.copy()

    enriched["playtime_range"] = enriched["max_playtime"] - enriched["min_playtime"]
    enriched["player_range"] = enriched["max_players"] - enriched["min_players"]

    enriched["category_count"] = enriched["categories"].apply(
        lambda x: len(extract_label_list(x))
    )
    enriched["mechanic_count"] = enriched["mechanics"].apply(
        lambda x: len(extract_label_list(x))
    )

    enriched["decade"] = (enriched["year_published"] // 10) * 10

    enriched["rating_tier"] = pd.cut(
        enriched["average_rating"],
        bins=[0, 4, 5.5, 6.5, 7.5, 10],
        labels=["poor", "below_avg", "average", "good", "excellent"],
    )

    enriched["popularity_tier"] = pd.qcut(
        enriched["users_rated"].rank(method="first"),
        q=4,
        labels=["niche", "low", "moderate", "popular"],
    )

    return enriched


def log_scale(series: pd.Series) -> pd.Series:
    """Apply log1p transformation to reduce skewness."""
    return np.log1p(series)


def preprocess(df: pd.DataFrame, min_ratings: int = 30) -> pd.DataFrame:
    """Full preprocessing pipeline: clean, fill, filter, enrich."""
    return (
        df
        .pipe(clean_outliers)
        .pipe(fill_missing)
        .pipe(filter_min_ratings, min_ratings=min_ratings)
        .pipe(add_derived_features)
    )
