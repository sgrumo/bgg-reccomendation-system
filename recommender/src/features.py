"""Feature extraction and encoding for board game data."""

import json

import pandas as pd
from sklearn.preprocessing import MultiLabelBinarizer, MinMaxScaler


def extract_names_from_json(raw: list[dict] | str | None) -> list[str]:
    """Extract 'name' values from a JSON array of objects."""
    if raw is None:
        return []
    if isinstance(raw, str):
        raw = json.loads(raw)
    return [item["name"] for item in raw if "name" in item]


def encode_multi_label(
    series: pd.Series, prefix: str
) -> tuple[pd.DataFrame, MultiLabelBinarizer]:
    """One-hot encode a series of string lists into a binary DataFrame."""
    mlb = MultiLabelBinarizer()
    encoded = mlb.fit_transform(series)
    columns = [f"{prefix}_{name}" for name in mlb.classes_]
    return pd.DataFrame(encoded, columns=columns, index=series.index), mlb


def build_feature_matrix(df: pd.DataFrame) -> pd.DataFrame:
    """Build a feature matrix from raw board game data.

    Combines numeric features (scaled) with one-hot encoded
    categories, mechanics, and families.
    """
    numeric_cols = [
        "min_players", "max_players", "min_playtime", "max_playtime",
        "min_age", "average_weight",
    ]

    numeric = df[numeric_cols].fillna(0)
    scaler = MinMaxScaler()
    numeric_scaled = pd.DataFrame(
        scaler.fit_transform(numeric),
        columns=numeric_cols,
        index=df.index,
    )

    categories = df["categories"].apply(extract_names_from_json)
    mechanics = df["mechanics"].apply(extract_names_from_json)
    families = df["families"].apply(extract_names_from_json)

    cat_encoded, _ = encode_multi_label(categories, "cat")
    mech_encoded, _ = encode_multi_label(mechanics, "mech")
    fam_encoded, _ = encode_multi_label(families, "fam")

    return pd.concat(
        [numeric_scaled, cat_encoded, mech_encoded, fam_encoded],
        axis=1,
    )
