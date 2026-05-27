"""Feature extraction and encoding for board game data."""

import json

import numpy as np
import pandas as pd
from scipy.sparse import csr_matrix, hstack
from sklearn.preprocessing import MultiLabelBinarizer, MinMaxScaler


def extract_names_from_json(raw: list[dict] | str | None) -> list[str]:
    """Extract 'name' values from a JSON array of objects."""
    if raw is None:
        return []
    if isinstance(raw, str):
        raw = json.loads(raw)
    return [item.get("value") or item.get("name") for item in raw if item.get("value") or item.get("name")]


def encode_multi_label_sparse(series: pd.Series) -> csr_matrix:
    """One-hot encode a series of string lists into a sparse matrix."""
    mlb = MultiLabelBinarizer(sparse_output=True)
    return mlb.fit_transform(series).tocsr()


def build_feature_matrix(df: pd.DataFrame) -> csr_matrix:
    """Build a sparse feature matrix from raw board game data.

    Combines scaled numeric features with one-hot encoded
    categories, mechanics, and families. Returns a CSR matrix
    so row slicing in recommendation calls is fast.
    """
    numeric_cols = [
        "min_players", "max_players", "min_playtime", "max_playtime",
        "min_age", "average_weight",
    ]

    numeric = df[numeric_cols].fillna(0).to_numpy(dtype=np.float32)
    scaler = MinMaxScaler()
    numeric_scaled = csr_matrix(scaler.fit_transform(numeric))

    categories = df["categories"].apply(extract_names_from_json)
    mechanics = df["mechanics"].apply(extract_names_from_json)
    families = df["families"].apply(extract_names_from_json)

    cat_encoded = encode_multi_label_sparse(categories)
    mech_encoded = encode_multi_label_sparse(mechanics)
    fam_encoded = encode_multi_label_sparse(families)

    return hstack(
        [numeric_scaled, cat_encoded, mech_encoded, fam_encoded],
        format="csr",
    )
